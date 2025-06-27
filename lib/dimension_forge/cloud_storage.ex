defmodule DimensionForge.CloudStorage do
  @moduledoc """
  GCP Cloud Storage integration for image uploads and downloads
  """

  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Model.Object

  @doc """
  Upload original image to Cloud Storage
  """
  def upload_original(file_path, project_name, image_id, original_filename) do
    bucket = get_bucket_name()
    object_name = build_original_path(project_name, image_id, original_filename)

    upload_file(file_path, bucket, object_name)
  end

  @doc """
  Upload processed variant to Cloud Storage
  """
  def upload_variant(file_path, project_name, image_id, width, height, format) do
    bucket = get_bucket_name()
    object_name = build_variant_path(project_name, image_id, width, height, format)

    upload_file(file_path, bucket, object_name)
  end

  @doc """
  Download original image for on-demand processing
  """
  def download_original(original_url) do
    bucket = get_bucket_name()
    
    object_name = case original_url do
      # Handle URLs that start with "https://storage.googleapis.com/"
      "https://storage.googleapis.com/" <> rest ->
        case String.split(rest, "/", parts: 2) do
          [_bucket, path] -> path
          [path] -> path
        end
      
      # Handle bucket/object format
      _ ->
        case String.split(original_url, "/", parts: 2) do
          [_bucket, path] -> path
          [path] -> path
        end
    end

    download_file(bucket, object_name)
  end

  @doc """
  Generate a signed URL for direct access to an image
  """
  def generate_signed_url(filename, expiry_minutes \\ 60) do
    {:ok, token} = Goth.fetch(DimensionForge.Goth)
    bucket = get_bucket_name()

    # Calculate expiry time as Unix timestamp
    expiry_timestamp =
      DateTime.utc_now()
      |> DateTime.add(expiry_minutes * 60, :second)
      |> DateTime.to_unix()

    # Create the signed URL using query parameters for temporary access
    base_url = "https://storage.googleapis.com/#{bucket}/#{filename}"
    signed_url = "#{base_url}?access_token=#{token.token}&expires=#{expiry_timestamp}"

    {:ok, signed_url}
  end

  @doc """
  Serve image from storage using signed URL redirect
  """
  def serve_image_from_storage(storage_url) do
    object_name = case storage_url do
      # Handle URLs that start with "https://storage.googleapis.com/"
      "https://storage.googleapis.com/" <> rest ->
        case String.split(rest, "/", parts: 2) do
          [_bucket, path] -> path
          [path] -> path
        end
      
      # Handle bucket/object format
      _ ->
        case String.split(storage_url, "/", parts: 2) do
          [_bucket, path] -> path
          [path] -> path
        end
    end
    
    generate_signed_url(object_name)
  end

  @doc """
  Delete a variant from cloud storage
  """
  def delete_variant(object_name) do
    bucket = get_bucket_name()
    
    with {:ok, conn} <- get_connection() do
      case Objects.storage_objects_delete(conn, bucket, object_name) do
        {:ok, _} -> :ok
        {:error, error} -> {:error, "Failed to delete variant: #{inspect(error)}"}
      end
    else
      {:error, error} -> {:error, error}
    end
  end

  # Private functions

  defp upload_file(file_path, bucket, object_name) do
    IO.inspect({file_path, bucket, object_name}, label: "5. Upload file params")

    with {:ok, conn} <- get_connection() |> IO.inspect(label: "5. GCP connection") do
      IO.inspect("Starting GCS upload...", label: "5. Upload start")

      case Objects.storage_objects_insert_simple(
             conn,
             bucket,
             "multipart",
             %{name: object_name},
             file_path
           ) do
        {:ok, object} ->
          IO.inspect(object, label: "5. GCS upload success")
          public_url = build_public_url(bucket, object_name)
          IO.inspect(public_url, label: "5. Generated public URL")
          {:ok, public_url}

        {:error, error} ->
          IO.inspect(error, label: "5. GCS upload error")
          {:error, "Upload failed: #{inspect(error)}"}
      end
    else
      {:error, error} ->
        IO.inspect(error, label: "5. Connection error")
        {:error, "Connection failed: #{inspect(error)}"}
    end
  end

  defp download_file(bucket, object_name) do
    temp_dir = System.tmp_dir!()
    temp_filename = "download_#{UUID.uuid4()}_#{Path.basename(object_name)}"
    temp_path = Path.join(temp_dir, temp_filename)

    with {:ok, conn} <- get_connection(),
         {:ok, %Tesla.Env{body: content}} <-
           Objects.storage_objects_get(
             conn,
             bucket,
             object_name,
             alt: "media"
           ),
         :ok <- File.write(temp_path, content) do
      {:ok, temp_path}
    else
      error -> {:error, "Download failed: #{inspect(error)}"}
    end
  end

  defp get_connection do
    IO.inspect("Getting GCP connection...", label: "5. Auth step")

    case Goth.fetch(DimensionForge.Goth) |> IO.inspect(label: "5. Goth token fetch") do
      {:ok, token} ->
        IO.inspect(token, label: "5. Retrieved token")
        conn = GoogleApi.Storage.V1.Connection.new(token.token)
        IO.inspect(conn, label: "5. Created connection")
        {:ok, conn}

      error ->
        {:error, "Failed to get auth token: #{inspect(error)}"}
    end
  end

  defp get_bucket_name do
    bucket =
      System.get_env("GCP_BUCKET_NAME") ||
        raise "GCP_BUCKET_NAME environment variable is required"

    IO.inspect(bucket, label: "5. Using bucket")
    bucket
  end

  defp build_original_path(project_name, image_id, original_filename) do
    "originals/#{project_name}/#{image_id}/#{original_filename}"
  end

  defp build_variant_path(project_name, image_id, width, height, format) do
    "variants/#{project_name}/#{image_id}/#{width}x#{height}.#{format}"
  end

  defp build_public_url(bucket, object_name) do
    "https://storage.googleapis.com/#{bucket}/#{object_name}"
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".bmp" -> "image/bmp"
      ".tiff" -> "image/tiff"
      ".svg" -> "image/svg+xml"
      _ -> "application/octet-stream"
    end
  end
end
