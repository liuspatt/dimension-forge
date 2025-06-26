defmodule DimensionForgeWeb.ImageController do
  use DimensionForgeWeb, :controller
  
  alias DimensionForge.Images
  alias DimensionForge.CloudStorage
  alias DimensionForge.ImageProcessor
  
  # Upload endpoint - requires API key authentication
  def upload(conn, params) do
    IO.inspect(params, label: "1. API Request params")
    with {:ok, validated_params} <- validate_upload_params(params),
         {:ok, image_data} <- process_upload(validated_params.image, validated_params.project_name),
         {:ok, image} <- (Images.create_image(image_data) |> IO.inspect(label: "7. Database storage")) do
      
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
  def show(conn, %{"project_name" => project_name, "image_id" => image_id, 
                   "width" => width, "height" => height, "filename" => filename}) do
    
    case Images.get_image(project_name, image_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Image not found"})
        
      image ->
        format = extract_format(filename)
        width_int = String.to_integer(width)
        height_int = String.to_integer(height)
        
        case get_or_create_variant(image, width_int, height_int, format) do
          {:ok, url} ->
            conn
            |> redirect(external: url)
            
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: reason})
        end
    end
  end
  
  # URL-based image resizing endpoint - /300/200/image.webp
  def resize_url(conn, %{"width" => width, "height" => height, "filename" => filename}) do
    # Extract project_name and image_id from request path or headers
    # For this endpoint, we'll expect them as query parameters or in a specific URL structure
    project_name = conn.params["project_name"] || get_req_header(conn, "x-project-name") |> List.first()
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
              
              case get_or_create_variant(image, width_int, height_int, format) do
                {:ok, url} ->
                  conn
                  |> redirect(external: url)
                  
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
        # Use project_name if provided, otherwise default from key or fallback
        project_name = params["project_name"] || extract_project_from_key(params["key"]) || "default"
        
        validated = %{
          image: params["image"],
          project_name: project_name,
          api_key: params["key"]
        }
        IO.inspect(validated, label: "2. Validated params")
        {:ok, validated}
    end
  end
  
  defp extract_project_from_key(_key) do
    # For now, return default project. In the future, you could:
    # 1. Look up the API key in the database to get associated project
    # 2. Decode project info from the key structure
    # 3. Use a mapping configuration
    "default"
  end
  
  defp process_upload(image_params, project_name) do
    IO.inspect({image_params, project_name}, label: "3. Upload Processing start")
    image_id = UUID.uuid4()
    original_filename = image_params.filename
    content_type = image_params.content_type
    IO.inspect({image_id, original_filename, content_type}, label: "3. Generated metadata")
    
    # Validate image
    with :ok <- (validate_image(image_params) |> IO.inspect(label: "3. Image validation")),
         {:ok, temp_path} <- (save_temp_file(image_params) |> IO.inspect(label: "3. Temp file saved")),
         {:ok, dimensions} <- (ImageProcessor.get_dimensions(temp_path) |> IO.inspect(label: "4. Image analysis")),
         {:ok, original_url} <- (CloudStorage.upload_original(temp_path, project_name, image_id, original_filename) |> IO.inspect(label: "5. Original upload")),
         {:ok, variants} <- (create_variants(temp_path, project_name, image_id, original_filename) |> IO.inspect(label: "6. Variant generation")) do
      
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
        variants: variants
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
  
  defp get_or_create_variant(image, width, height, format) do
    variant_key = "#{width}x#{height}_#{format}"
    
    case Map.get(image.variants, variant_key) do
      nil ->
        # Variant doesn't exist, create it on demand
        create_on_demand_variant(image, width, height, format)
        
      url ->
        {:ok, url}
    end
  end
  
  defp create_on_demand_variant(image, width, height, format) do
    # Download original, process, upload variant, update database
    with {:ok, temp_path} <- CloudStorage.download_original(image.original_url),
         {:ok, processed_path} <- ImageProcessor.resize_and_convert(temp_path, width, height, format),
         {:ok, url} <- CloudStorage.upload_variant(processed_path, image.project_name, image.image_id, width, height, format),
         {:ok, _updated_image} <- Images.add_variant(image, "#{width}x#{height}_#{format}", url) do
      
      File.rm(temp_path)
      File.rm(processed_path)
      {:ok, url}
    else
      error -> error
    end
  end
  
  defp extract_format(filename) do
    filename
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.downcase()
  end
  
end