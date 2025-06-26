defmodule DimensionForge.ImageProcessor do
  @moduledoc """
  Image processing utilities using Mogrify (ImageMagick)
  """


  @doc """
  Get image dimensions
  """
  def get_dimensions(file_path) do
    try do
      %{width: width, height: height} =
        file_path
        |> Mogrify.open()
        |> Mogrify.verbose()

      {:ok, %{width: width, height: height}}
    rescue
      error -> {:error, "Failed to get image dimensions: #{inspect(error)}"}
    end
  end

  @doc """
  Resize image and convert to specified format using ImageMagick
  """
  def resize_and_convert(input_path, width, height, format) do
    temp_dir = System.tmp_dir!()
    output_filename = "processed_#{UUID.uuid4()}_#{width}x#{height}.#{format}"
    output_path = Path.join(temp_dir, output_filename)

    try do
      input_path
      |> Mogrify.open()
      |> resize_image(width, height)
      |> convert_format(format)
      |> optimize_image(format)
      |> Mogrify.save(path: output_path)

      {:ok, output_path}
    rescue
      error -> {:error, "Failed to process image: #{inspect(error)}"}
    end
  end

  @doc """
  Generate all default size variants for an image
  """
  def generate_default_variants(input_path, project_name, image_id, _original_filename) do
    default_sizes = get_default_sizes()
    webp_enabled = webp_enabled?()

    variants = %{}

    # Generate variants for each default size
    Enum.reduce_while(default_sizes, {:ok, variants}, fn size, {:ok, acc} ->
      [width, height] = String.split(size, "x") |> Enum.map(&String.to_integer/1)

      # Generate JPG variant (always)
      case create_single_variant(input_path, width, height, "jpg") do
        {:ok, jpg_path} ->
          case DimensionForge.CloudStorage.upload_variant(jpg_path, project_name, image_id, width, height, "jpg") do
            {:ok, jpg_url} ->
              File.rm(jpg_path)
              updated_acc = Map.put(acc, "#{width}x#{height}_jpg", jpg_url)

              # Generate WebP variant if enabled
              if webp_enabled do
                case create_single_variant(input_path, width, height, "webp") do
                  {:ok, webp_path} ->
                    case DimensionForge.CloudStorage.upload_variant(webp_path, project_name, image_id, width, height, "webp") do
                      {:ok, webp_url} ->
                        File.rm(webp_path)
                        final_acc = Map.put(updated_acc, "#{width}x#{height}_webp", webp_url)
                        {:cont, {:ok, final_acc}}

                      error ->
                        File.rm(webp_path)
                        {:halt, error}
                    end

                  error ->
                    {:halt, error}
                end
              else
                {:cont, {:ok, updated_acc}}
              end

            error ->
              File.rm(jpg_path)
              {:halt, error}
          end

        error ->
          {:halt, error}
      end
    end)
  end

  defp create_single_variant(input_path, width, height, format) do
    temp_dir = System.tmp_dir!()
    output_filename = "variant_#{UUID.uuid4()}_#{width}x#{height}.#{format}"
    output_path = Path.join(temp_dir, output_filename)

    try do
      input_path
      |> Mogrify.open()
      |> resize_image(width, height)
      |> convert_format(format)
      |> optimize_image(format)
      |> Mogrify.save(path: output_path)

      {:ok, output_path}
    rescue
      error -> {:error, "Failed to create variant: #{inspect(error)}"}
    end
  end

  # Private functions

  defp resize_image(image, width, height) do
    # Resize maintaining aspect ratio, fitting within bounds
    image
    |> Mogrify.resize("#{width}x#{height}>")
    |> Mogrify.extent("#{width}x#{height}")
    |> Mogrify.gravity("center")
  end

  defp convert_format(image, "webp") do
    quality = get_webp_quality()

    image
    |> Mogrify.format("webp")
    |> Mogrify.quality(quality)
  end

  defp convert_format(image, "jpg") do
    quality = get_jpg_quality()

    image
    |> Mogrify.format("jpg")
    |> Mogrify.quality(quality)
  end

  defp convert_format(image, "jpeg") do
    quality = get_jpg_quality()

    image
    |> Mogrify.format("jpeg")
    |> Mogrify.quality(quality)
  end

  defp convert_format(image, "png") do
    image
    |> Mogrify.format("png")
    |> optimize_png()
  end

  defp convert_format(image, format) do
    # For other formats, just convert without specific optimizations
    Mogrify.format(image, format)
  end

  defp optimize_image(image, "webp") do
    # WebP-specific optimizations
    image
    |> Mogrify.custom("define", "webp:lossless=false")
    |> Mogrify.custom("define", "webp:method=6") # Best compression
  end

  defp optimize_image(image, "jpg") do
    # JPEG optimizations
    image
    |> Mogrify.custom("sampling-factor", "4:2:0")
    |> Mogrify.custom("colorspace", "RGB")
    |> Mogrify.custom("interlace", "Plane")
  end

  defp optimize_image(image, "jpeg") do
    optimize_image(image, "jpg")
  end

  defp optimize_image(image, "png") do
    # PNG optimizations are handled in optimize_png/1
    image
  end

  defp optimize_image(image, _format) do
    # No specific optimizations for other formats
    image
  end

  defp optimize_png(image) do
    compression = get_png_compression()

    image
    |> Mogrify.custom("define", "png:compression-level=#{compression}")
    |> Mogrify.custom("define", "png:compression-strategy=1")
    |> Mogrify.custom("define", "png:compression-filter=5")
  end

  defp get_webp_quality do
    System.get_env("DEFAULT_WEBP_QUALITY", "80")
    |> String.to_integer()
  end

  defp get_jpg_quality do
    System.get_env("DEFAULT_JPG_QUALITY", "85")
    |> String.to_integer()
  end

  defp get_png_compression do
    System.get_env("DEFAULT_PNG_COMPRESSION", "6")
    |> String.to_integer()
  end

  defp get_default_sizes do
    System.get_env("DEFAULT_SIZES", "150x150,300x300,600x600,1200x1200")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp webp_enabled? do
    System.get_env("ENABLE_WEBP", "true") == "true"
  end

  def is_format_supported?(format) do
    supported_formats = get_supported_formats()
    format in supported_formats
  end

  def get_supported_formats do
    System.get_env("SUPPORTED_FORMATS", "webp,jpg,jpeg,png,gif")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end
end
