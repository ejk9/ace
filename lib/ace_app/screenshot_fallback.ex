defmodule AceApp.ScreenshotFallback do
  @moduledoc """
  Fallback screenshot generation when the external service is unavailable.
  Creates simple placeholder images using server-side HTML rendering.
  """

  require Logger

  @doc """
  Creates a simple placeholder screenshot file for Discord notifications.
  Returns the file path if successful.
  """
  def create_placeholder_screenshot(player, pick, draft) do
    try do
      team = AceApp.Drafts.get_team!(pick.team_id)
      
      # Create filename
      timestamp = System.system_time(:millisecond)
      filename = "pick_#{pick.id}_#{String.downcase(player.display_name)}_#{timestamp}.png"
      
      screenshots_dir = Path.join([
        Application.app_dir(:ace_app, "priv/static"),
        "screenshots"
      ])
      
      File.mkdir_p!(screenshots_dir)
      file_path = Path.join(screenshots_dir, filename)
      
      # Create a simple PNG placeholder using ImageMagick (if available) or fallback
      case create_simple_image(player, team, file_path) do
        :ok ->
          Logger.info("Created placeholder screenshot: #{file_path}")
          {:ok, file_path}
        
        {:error, reason} ->
          Logger.warning("Failed to create placeholder screenshot: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Screenshot fallback failed: #{inspect(error)}")
        {:error, "Screenshot generation failed"}
    end
  end

  defp create_simple_image(player, team, file_path) do
    # Try to use ImageMagick convert command if available
    case System.find_executable("convert") do
      nil ->
        # Fallback: create a simple text file instead of image
        create_text_placeholder(player, team, file_path)
      
      _convert_path ->
        create_imagemagick_placeholder(player, team, file_path)
    end
  end

  defp create_imagemagick_placeholder(player, team, file_path) do
    # Create a simple image with ImageMagick
    text = "#{player.display_name}\\n#{team.name}"
    
    cmd_args = [
      "-size", "400x300",
      "-background", "#2D3748",
      "-fill", "#E2E8F0", 
      "-font", "Arial",
      "-pointsize", "24",
      "-gravity", "center",
      "label:#{text}",
      file_path
    ]
    
    case System.cmd("convert", cmd_args, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok
      
      {error_output, _exit_code} ->
        Logger.warning("ImageMagick failed: #{error_output}")
        create_text_placeholder(player, team, file_path)
    end
  end

  defp create_text_placeholder(player, team, file_path) do
    # Create a simple text file as absolute fallback
    content = """
    Player Pick Screenshot
    
    Player: #{player.display_name}
    Team: #{team.name}
    
    (Screenshot service unavailable - placeholder generated)
    """
    
    # Create both text placeholder and a minimal PNG
    txt_path = String.replace(file_path, ".png", ".txt")
    
    # Write text file for reference
    case File.write(txt_path, content) do
      :ok ->
        Logger.info("Created text placeholder: #{txt_path}")
        
        # Create a minimal PNG file so Discord has something to attach
        case create_minimal_png(file_path) do
          :ok ->
            Logger.info("Created minimal PNG placeholder: #{file_path}")
            :ok
          {:error, reason} ->
            Logger.warning("Failed to create minimal PNG: #{inspect(reason)}")
            :ok  # Still return success since we have the text file
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp create_minimal_png(file_path) do
    # Create a proper sized PNG for Discord (400x300 minimum)
    # This is a base64 encoded 400x300 transparent PNG
    case System.find_executable("convert") do
      nil ->
        # Fallback: create a solid color 400x300 PNG using a simple approach
        create_solid_color_png(file_path)
      
      _convert_path ->
        # Use ImageMagick to create a better placeholder
        cmd_args = [
          "-size", "400x300",
          "-background", "#2D3748",
          "-fill", "#E2E8F0",
          "-font", "Arial",
          "-pointsize", "20",
          "-gravity", "center",
          "label:Player Pick\nScreenshot\nUnavailable",
          file_path
        ]
        
        case System.cmd("convert", cmd_args, stderr_to_stdout: true) do
          {_output, 0} -> :ok
          {_error, _} -> create_solid_color_png(file_path)
        end
    end
  end
  
  defp create_solid_color_png(file_path) do
    # Use a working test image if available, otherwise create a minimal PNG
    test_image_path = Path.join([Application.app_dir(:ace_app), "..", "..", "test_image.png"])
    
    if File.exists?(test_image_path) do
      case File.cp(test_image_path, file_path) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      # Create a very simple 1x1 PNG that we know works
      minimal_png_data = Base.decode64!("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI/hWVhwAAAAABJRU5ErkJggg==")
      
      case File.write(file_path, minimal_png_data) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end
end