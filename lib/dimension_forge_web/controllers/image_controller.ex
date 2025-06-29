defmodule DimensionForgeWeb.ImageController do
  use DimensionForgeWeb, :controller

  alias DimensionForge.Images
  alias DimensionForge.CloudStorage
  alias DimensionForge.ImageProcessor

  # Upload endpoint - requires API key authentication
  def upload(conn, params) do
    IO.inspect(params, label: "1. API Request params")

    with {:ok, validated_params} <- validate_upload_params(params),
         {:ok, image_data} <-
           process_upload(validated_params.image, validated_params.project_name, validated_params.api_key_id),
         {:ok, image} <-
           Images.create_image(image_data) |> IO.inspect(label: "7. Database storage") do
      response_data = %{
        success: true,
        data: %{
          image_id: image.image_id,
          project_name: image.project_name,
          original_url: image.original_url,
          formats: image.formats,
          variants: image.variants
        }
      }

      IO.inspect(response_data, label: "8. Response data")

      conn
      |> put_status(:created)
      |> json(response_data)
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: reason})
    end
  end

  # Get image endpoint - public access
  def show(conn, %{
        "project_name" => project_name,
        "image_id" => image_id,
        "width" => width,
        "height" => height,
        "filename" => filename
      }) do
    case Images.get_image(project_name, image_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Image not found"})

      image ->
        format = extract_format(filename)
        width_int = String.to_integer(width)
        height_int = String.to_integer(height)

        resize_mode = conn.params["mode"] || conn.query_params["mode"] || "crop"

        case get_or_create_variant(image, width_int, height_int, format, resize_mode) do
          {:ok, url} ->
            serve_image_from_storage(conn, url, format)

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: reason})
        end
    end
  end

  # Reset all variants for an image
  def reset_variants(conn, %{"id" => image_id}) do
    project_name = conn.params["project_name"] || get_req_header(conn, "x-project-name") |> List.first() || "default"

    case Images.get_image(project_name, image_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Image not found"})

      image ->
        case delete_all_variants(image) do
          :ok ->
            case Images.clear_variants(image) do
              {:ok, updated_image} ->
                conn
                |> json(%{
                  success: true,
                  message: "All variants reset successfully",
                  data: %{
                    image_id: updated_image.image_id,
                    variants_cleared: map_size(image.variants)
                  }
                })

              {:error, reason} ->
                conn
                |> put_status(:internal_server_error)
                |> json(%{error: "Failed to update database: #{reason}"})
            end

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to delete variants from storage: #{reason}"})
        end
    end
  end

  # Reset all variants for all images in a project
  def reset_all_variants(conn, _params) do
    project_name = conn.params["project_name"] || get_req_header(conn, "x-project-name") |> List.first() || "default"

    case reset_all_images_variants(project_name) do
      {:ok, results} ->
        conn
        |> json(%{
          success: true,
          message: "All image variants reset successfully",
          data: %{
            project_name: project_name,
            images_processed: results.images_processed,
            total_variants_cleared: results.total_variants_cleared,
            errors: results.errors
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to reset all variants: #{reason}"})
    end
  end

  # URL-based image resizing endpoint - /300/200/image.webp
  def resize_url(conn, %{"width" => width, "height" => height, "filename" => filename}) do
    # Extract project_name and image_id from request path or headers
    # For this endpoint, we'll expect them as query parameters or in a specific URL structure
    project_name =
      conn.params["project_name"] || get_req_header(conn, "x-project-name") |> List.first()

    image_id = conn.params["image_id"] || get_req_header(conn, "x-image-id") |> List.first()

    cond do
      is_nil(project_name) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "project_name is required (query param or X-Project-Name header)"})

      is_nil(image_id) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "image_id is required (query param or X-Image-Id header)"})

      true ->
        format = extract_format(filename)

        # Validate format is supported
        unless ImageProcessor.is_format_supported?(format) do
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Unsupported format: #{format}"})
        else
          case Images.get_image(project_name, image_id) do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "Image not found"})

            image ->
              width_int = String.to_integer(width)
              height_int = String.to_integer(height)

              resize_mode = conn.params["mode"] || conn.query_params["mode"] || "crop"

              case get_or_create_variant(image, width_int, height_int, format, resize_mode) do
                {:ok, url} ->
                  serve_image_from_storage(conn, url, format)

                {:error, reason} ->
                  conn
                  |> put_status(:internal_server_error)
                  |> json(%{error: reason})
              end
          end
        end
    end
  end

  # Private functions

  defp validate_upload_params(params) do
    IO.inspect(params, label: "2. Parameter Validation")

    cond do
      not Map.has_key?(params, "image") ->
        {:error, "Missing required parameter: image"}

      not Map.has_key?(params, "project_name") and not Map.has_key?(params, "key") ->
        {:error, "Missing required parameter: project_name or key"}

      true ->
        # Get API key info to extract project_name and api_key_id
        {project_name, api_key_id} = extract_project_and_key_id(params["key"], params["project_name"])

        validated = %{
          image: params["image"],
          project_name: project_name,
          api_key: params["key"],
          api_key_id: api_key_id
        }

        IO.inspect(validated, label: "2. Validated params")
        {:ok, validated}
    end
  end

  defp extract_project_from_key(key) do
    case DimensionForge.ApiKeys.get_api_key_by_key(key) do
      %DimensionForge.ApiKey{project_name: project_name} when not is_nil(project_name) ->
        project_name
      _ ->
        "default"
    end
  end

  defp extract_project_and_key_id(key, provided_project_name) do
    case DimensionForge.ApiKeys.get_api_key_by_key(key) do
      %DimensionForge.ApiKey{id: api_key_id, project_name: api_project_name} when not is_nil(api_project_name) ->
        # Use provided project_name if given, otherwise use API key's project_name
        project_name = provided_project_name || api_project_name
        {project_name, api_key_id}
      _ ->
        # Default project with no API key ID
        project_name = provided_project_name || "default"
        {project_name, nil}
    end
  end

  defp process_upload(image_params, project_name, api_key_id \\ nil) do
    IO.inspect({image_params, project_name, api_key_id}, label: "3. Upload Processing start")
    image_id = UUID.uuid4()
    original_filename = image_params.filename
    content_type = image_params.content_type
    IO.inspect({image_id, original_filename, content_type}, label: "3. Generated metadata")

    # Validate image
    with :ok <- validate_image(image_params) |> IO.inspect(label: "3. Image validation"),
         {:ok, temp_path} <-
           save_temp_file(image_params) |> IO.inspect(label: "3. Temp file saved"),
         {:ok, dimensions} <-
           ImageProcessor.get_dimensions(temp_path) |> IO.inspect(label: "4. Image analysis"),
         {:ok, original_url} <-
           CloudStorage.upload_original(temp_path, project_name, image_id, original_filename)
           |> IO.inspect(label: "5. Original upload"),
         {:ok, variants} <-
           create_variants(temp_path, project_name, image_id, original_filename)
           |> IO.inspect(label: "6. Variant generation") do
      File.rm(temp_path)

      image_data = %{
        project_name: project_name,
        image_name: Path.basename(original_filename, Path.extname(original_filename)),
        image_id: image_id,
        original_filename: original_filename,
        original_url: original_url,
        content_type: content_type,
        file_size: File.stat!(image_params.path).size,
        width: dimensions.width,
        height: dimensions.height,
        formats: ImageProcessor.get_supported_formats(),
        variants: variants,
        api_key_id: api_key_id
      }

      IO.inspect(image_data, label: "6. Final image data")
      {:ok, image_data}
    else
      error -> error
    end
  end

  defp validate_image(image_params) do
    max_size_mb = String.to_integer(System.get_env("MAX_IMAGE_SIZE_MB", "10"))
    max_size_bytes = max_size_mb * 1024 * 1024

    cond do
      not String.starts_with?(image_params.content_type, "image/") ->
        {:error, "File must be an image"}

      File.stat!(image_params.path).size > max_size_bytes ->
        {:error, "File size exceeds #{max_size_mb}MB limit"}

      true ->
        :ok
    end
  end

  defp save_temp_file(image_params) do
    temp_dir = System.tmp_dir!()
    temp_filename = "#{UUID.uuid4()}_#{image_params.filename}"
    temp_path = Path.join(temp_dir, temp_filename)

    case File.cp(image_params.path, temp_path) do
      :ok -> {:ok, temp_path}
      error -> {:error, "Failed to save temporary file: #{inspect(error)}"}
    end
  end

  defp create_variants(temp_path, project_name, image_id, original_filename) do
    # Generate all default size variants using ImageMagick
    ImageProcessor.generate_default_variants(temp_path, project_name, image_id, original_filename)
  end

  defp get_or_create_variant(image, width, height, format, resize_mode \\ nil) do
    variant_key = "#{width}x#{height}_#{format}"

    case Map.get(image.variants, variant_key) do
      nil ->
        # Variant doesn't exist, create it on demand
        create_on_demand_variant(image, width, height, format, resize_mode)

      url ->
        {:ok, url}
    end
  end

  defp create_on_demand_variant(image, width, height, format, resize_mode \\ nil) do
    # Download original, process, upload variant, update database
    with {:ok, temp_path} <- CloudStorage.download_original(image.original_url),
         {:ok, processed_path} <-
           ImageProcessor.resize_and_convert(temp_path, width, height, format, resize_mode),
         {:ok, url} <-
           CloudStorage.upload_variant(
             processed_path,
             image.project_name,
             image.image_id,
             width,
             height,
             format
           ),
         {:ok, _updated_image} <- Images.add_variant(image, "#{width}x#{height}_#{format}", url) do
      File.rm(temp_path)
      File.rm(processed_path)
      {:ok, url}
    else
      error -> error
    end
  end

  defp serve_image_from_storage(conn, storage_url, _format) do
    case CloudStorage.serve_image_from_storage(storage_url) do
      {:ok, signed_url} ->
        conn
        |> redirect(external: signed_url)

      {:error, _reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Image not found"})
    end
  end

  defp get_content_type_for_format(format) do
    case String.downcase(format) do
      "jpg" -> "image/jpeg"
      "jpeg" -> "image/jpeg"
      "png" -> "image/png"
      "gif" -> "image/gif"
      "webp" -> "image/webp"
      "bmp" -> "image/bmp"
      "tiff" -> "image/tiff"
      "svg" -> "image/svg+xml"
      _ -> "application/octet-stream"
    end
  end

  defp delete_all_variants(image) do
    # Delete all variants from cloud storage
    Enum.reduce_while(image.variants, :ok, fn {variant_key, _url}, _acc ->
      object_name = build_variant_object_name(image.project_name, image.image_id, variant_key)

      case CloudStorage.delete_variant(object_name) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp reset_all_images_variants(project_name) do
    # Get all images in the project
    images = Images.list_images(project_name, limit: 1000)

    # Process each image
    results = Enum.reduce(images, %{images_processed: 0, total_variants_cleared: 0, errors: []}, fn image, acc ->
      case delete_all_variants(image) do
        :ok ->
          case Images.clear_variants(image) do
            {:ok, _updated_image} ->
              %{
                images_processed: acc.images_processed + 1,
                total_variants_cleared: acc.total_variants_cleared + map_size(image.variants),
                errors: acc.errors
              }

            {:error, reason} ->
              error_msg = "Failed to clear variants in database for image #{image.image_id}: #{reason}"
              %{acc | errors: [error_msg | acc.errors]}
          end

        {:error, reason} ->
          error_msg = "Failed to delete variants from storage for image #{image.image_id}: #{reason}"
          %{acc | errors: [error_msg | acc.errors]}
      end
    end)

    if length(results.errors) == 0 do
      {:ok, results}
    else
      {:ok, results}  # Return partial success with errors listed
    end
  end

  defp build_variant_object_name(project_name, image_id, variant_key) do
    # Parse variant key like "300x200_webp" to extract dimensions and format
    case String.split(variant_key, "_") do
      [dimensions, format] ->
        "variants/#{project_name}/#{image_id}/#{dimensions}.#{format}"
      _ ->
        # Fallback if key format is unexpected
        "variants/#{project_name}/#{image_id}/#{variant_key}"
    end
  end

  defp extract_format(filename) do
    filename
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.downcase()
  end
end
