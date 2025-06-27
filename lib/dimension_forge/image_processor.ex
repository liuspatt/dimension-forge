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
  Resize image and convert to specified format using ImageMagick + cwebp
  """
  def resize_and_convert(input_path, width, height, format, resize_mode \\ nil) do
    case format do
      "webp" ->
        resize_and_convert_to_webp(input_path, width, height, resize_mode)
      
      _ ->
        resize_and_convert_standard(input_path, width, height, format, resize_mode)
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
          case DimensionForge.CloudStorage.upload_variant(
                 jpg_path,
                 project_name,
                 image_id,
                 width,
                 height,
                 "jpg"
               ) do
            {:ok, jpg_url} ->
              File.rm(jpg_path)
              updated_acc = Map.put(acc, "#{width}x#{height}_jpg", jpg_url)

              # Generate WebP variant if enabled
              if webp_enabled do
                case create_single_variant(input_path, width, height, "webp") do
                  {:ok, webp_path} ->
                    case DimensionForge.CloudStorage.upload_variant(
                           webp_path,
                           project_name,
                           image_id,
                           width,
                           height,
                           "webp"
                         ) do
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
    case format do
      "webp" ->
        resize_and_convert_to_webp(input_path, width, height, nil)
      
      _ ->
        temp_dir = System.tmp_dir!()
        output_filename = "variant_#{UUID.uuid4()}_#{width}x#{height}.#{format}"
        output_path = Path.join(temp_dir, output_filename)

        try do
          input_path
          |> Mogrify.open()
          |> preserve_color_profile()
          |> resize_image(width, height, nil)
          |> convert_format(format)
          |> optimize_image(format)
          |> Mogrify.save(path: output_path)

          {:ok, output_path}
        rescue
          error -> {:error, "Failed to create variant: #{inspect(error)}"}
        end
    end
  end

  # Private functions

  defp resize_and_convert_to_webp(input_path, width, height, resize_mode) do
    temp_dir = System.tmp_dir!()
    
    # First resize with ImageMagick to PNG (lossless intermediate)
    intermediate_filename = "resized_#{UUID.uuid4()}_#{width}x#{height}.png"
    intermediate_path = Path.join(temp_dir, intermediate_filename)
    
    # Final WebP output
    output_filename = "processed_#{UUID.uuid4()}_#{width}x#{height}.webp"
    output_path = Path.join(temp_dir, output_filename)

    try do
      # Step 1: Resize with ImageMagick
      input_path
      |> Mogrify.open()
      |> preserve_color_profile()
      |> resize_image(width, height, resize_mode)
      |> Mogrify.format("png")
      |> Mogrify.save(path: intermediate_path)

      # Step 2: Convert to WebP with cwebp
      case convert_to_webp_with_cwebp(intermediate_path, output_path) do
        :ok ->
          File.rm(intermediate_path)
          {:ok, output_path}
        
        {:error, reason} ->
          File.rm(intermediate_path)
          {:error, reason}
      end
    rescue
      error -> 
        # Clean up intermediate file if it exists
        if File.exists?(intermediate_path), do: File.rm(intermediate_path)
        {:error, "Failed to process WebP image: #{inspect(error)}"}
    end
  end

  defp resize_and_convert_standard(input_path, width, height, format, resize_mode) do
    temp_dir = System.tmp_dir!()
    output_filename = "processed_#{UUID.uuid4()}_#{width}x#{height}.#{format}"
    output_path = Path.join(temp_dir, output_filename)

    try do
      input_path
      |> Mogrify.open()
      |> preserve_color_profile()
      |> resize_image(width, height, resize_mode)
      |> convert_format(format)
      |> optimize_image(format)
      |> Mogrify.save(path: output_path)

      {:ok, output_path}
    rescue
      error -> {:error, "Failed to process image: #{inspect(error)}"}
    end
  end

  defp convert_to_webp_with_cwebp(input_path, output_path) do
    quality = get_webp_quality()
    
    # Build cwebp command
    cmd_args = [
      "-q", "#{quality}",
      "-m", "6",  # Best compression method
      "-pass", "10",  # Number of analysis passes
      input_path,
      "-o", output_path
    ]

    case System.cmd("cwebp", cmd_args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {error_output, _exit_code} -> {:error, "cwebp failed: #{error_output}"}
    end
  rescue
    error -> {:error, "Failed to execute cwebp: #{inspect(error)}"}
  end

  defp resize_image(image, width, height, mode \\ nil) do
    # Use provided mode or get from environment variable
    resize_mode = mode || System.get_env("RESIZE_MODE", "crop")
    
    case resize_mode do
      "crop" ->
        # Crop to fill exact dimensions (no white space)
        image
        |> Mogrify.resize("#{width}x#{height}^")
        |> Mogrify.gravity("center")
        |> Mogrify.custom("crop", "#{width}x#{height}+0+0")
      
      "fit" ->
        # Fit within dimensions maintaining aspect ratio (may add white space)
        image
        |> Mogrify.resize("#{width}x#{height}>")
        |> Mogrify.extent("#{width}x#{height}")
        |> Mogrify.gravity("center")
      
      "stretch" ->
        # Stretch to exact dimensions (may distort image)
        image
        |> Mogrify.resize("#{width}x#{height}!")
      
      _ ->
        # Default to crop mode
        image
        |> Mogrify.resize_to_fill("#{width}x#{height}")
        |> Mogrify.gravity("center")
        |> Mogrify.extent("#{width}x#{height}")
    end
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
    # Minimal WebP optimizations
    image
  end

  defp optimize_image(image, "jpg") do
    # Minimal JPEG optimizations
    image
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

  # Private helper for color profile preservation
  defp preserve_color_profile(image) do
    image
    |> Mogrify.custom("auto-orient")
    |> Mogrify.custom("strip")
    |> Mogrify.custom("colorspace", "sRGB")
  end
end
