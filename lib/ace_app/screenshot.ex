defmodule AceApp.Screenshot do
  @moduledoc """
  Service for capturing screenshots of champion splash art HTML for Discord embeds.
  """

  require Logger

  @doc """
  Captures a screenshot of player popup HTML using Puppeteer service and returns the URL.
  The popup HTML shows:
  - Player name as hero text with gradient styling
  - Team name and color indicator
  - Player role badge
  - Champion splash art background
  - Professional draft confirmation layout
  """
  def capture_player_popup_html(player, pick, draft) do
    try do
      # Get additional context for the popup
      team = AceApp.Drafts.get_team!(pick.team_id)
      
      # Calculate round and pick information
      total_teams = length(AceApp.Drafts.list_teams(draft.id))
      round_number = div(pick.pick_number - 1, total_teams) + 1
      
      Logger.info("Screenshot capture requested for #{player.display_name} (#{team.name}) - Round #{round_number}, Pick #{pick.pick_number}")
      
      # Get champion data if player has one assigned
      champion_data = if player.champion_id do
        champion = AceApp.LoL.get_champion!(player.champion_id)
        skin_data = if player.preferred_skin_id do
          AceApp.LoL.get_champion_skin!(player.preferred_skin_id)
        else
          nil
        end
        
        %{
          champion_name: champion.name,
          champion_title: champion.title,
          champion_image: build_champion_splash_url(champion, player),
          skin_name: if(skin_data, do: skin_data.name, else: nil)
        }
      else
        %{champion_name: "", champion_title: "", champion_image: "", skin_name: ""}
      end
      
      # Build player data for screenshot
      player_data = %{
        player_name: player.display_name,
        team_name: team.name,
        team_color: get_team_color_class(team.pick_order_position),
        player_role: get_primary_role(player.preferred_roles),
        pick_number: pick.pick_number,
        round_number: round_number
      } |> Map.merge(champion_data)
      
      # Call the Node.js screenshot service
      case call_screenshot_service(player_data) do
        {:ok, response} ->
          screenshot_url = "#{get_base_url()}#{response["url"]}"
          Logger.info("Screenshot captured successfully: #{screenshot_url}")
          {:ok, screenshot_url}
        
        {:error, reason} ->
          Logger.error("Screenshot service failed: #{inspect(reason)}")
          {:error, "Screenshot capture failed"}
      end
    rescue
      error ->
        Logger.error("Failed to capture player popup screenshot: #{inspect(error)}")
        {:error, "Screenshot capture failed: #{inspect(error)}"}
    end
  end



  @doc """
  Captures a player popup screenshot and returns the local file path.
  This version returns the file path for Discord attachment uploads.
  """
  def capture_player_popup_file(player, pick, draft) do
    alias AceApp.Drafts
    alias AceApp.LoL
    
    try do
      team = Drafts.get_team!(pick.team_id)
      total_teams = length(Drafts.list_teams(draft.id))
      round_number = div(pick.pick_number - 1, total_teams) + 1
      
      Logger.info("Screenshot capture requested for #{player.display_name} (#{team.name}) - Round #{round_number}, Pick #{pick.pick_number}")
      
      # Get champion data if player has a champion assigned
      champion_data = if player.champion_id do
        champion = LoL.get_champion!(player.champion_id)
        
        # Get preferred skin data
        {skin_image, skin_name} = if player.preferred_skin_id do
          case LoL.get_champion_skin(player.champion_id, player.preferred_skin_id) do
            skin when not is_nil(skin) ->
              # Use the proper function to generate skin splash URL
              splash_url = LoL.get_skin_splash_url(champion, skin)
              skin_name = if skin.skin_id != 0, do: skin.name, else: ""
              {splash_url, skin_name}
            _ ->
              # Fallback to default champion image if skin not found
              {champion.image_url, ""}
          end
        else
          {champion.image_url, ""}
        end
        
        %{
          champion_name: champion.name,
          champion_title: champion.title,
          champion_image: skin_image,
          skin_name: skin_name
        }
      else
        %{champion_name: "", champion_title: "", champion_image: "", skin_name: ""}
      end
      
      # Build player data for screenshot
      player_data = %{
        player_name: player.display_name,
        team_name: team.name,
        team_color: get_team_color_class(team.pick_order_position),
        player_role: get_primary_role(player.preferred_roles),
        pick_number: pick.pick_number,
        round_number: round_number
      } |> Map.merge(champion_data)
      
      # Call the Node.js screenshot service
      case call_screenshot_service(player_data) do
        {:ok, response} ->
          # Return the local file path instead of URL
          file_path = Path.join([
            Application.app_dir(:ace_app, "priv/static"),
            "screenshots",
            response["filename"]
          ])
          Logger.info("Screenshot captured to file: #{file_path}")
          {:ok, file_path}
        
        {:error, reason} ->
          Logger.warning("Screenshot service failed (#{inspect(reason)}), skipping image")
          # Don't create fallback files, just return error so Discord sends without image
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Failed to capture player popup screenshot: #{inspect(error)}")
        {:error, "Screenshot capture failed: #{inspect(error)}"}
    end
  end

  @doc """
  Placeholder for future HTML-to-image screenshot implementation.
  This would capture the actual champion splash popup HTML content.
  """
  def capture_html_element(_html_content, _element_selector, _options \\ %{}) do
    # This is where we would implement actual screenshot capture
    # Options could include:
    # - width/height
    # - device scale factor
    # - background color
    # - wait conditions
    
    Logger.info("HTML screenshot capture not yet implemented, using fallback")
    {:error, "HTML screenshot capture not implemented"}
  end

  # Private helper functions

  defp call_screenshot_service(player_data) do
    service_url = get_screenshot_service_url()
    
    Logger.info("Screenshot: Calling service at #{service_url}/capture-player-popup")
    Logger.info("Screenshot: Player data: #{inspect(player_data)}")
    
    case Req.post(service_url <> "/capture-player-popup",
                  json: %{
                    playerData: player_data
                  },
                  receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: response}} ->
        Logger.info("Screenshot: Service responded successfully: #{inspect(response)}")
        {:ok, response}
      
      {:ok, %Req.Response{status: status, body: error_body}} ->
        Logger.error("Screenshot: Service returned HTTP #{status}: #{inspect(error_body)}")
        {:error, "HTTP #{status}: #{inspect(error_body)}"}
      
      {:error, reason} ->
        Logger.error("Screenshot: Network error: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp get_base_url do
    case Application.get_env(:ace_app, :base_url) do
      nil -> "http://localhost:4000"
      url -> url
    end
  end

  defp get_screenshot_service_url do
    case Application.get_env(:ace_app, :screenshot_service_url) do
      nil -> "http://localhost:3001"
      url -> url
    end
  end

  defp build_champion_splash_url(champion, player) do
    # Check if player has a specific skin selected
    skin_id = case player do
      %{preferred_skin_id: skin_id} when not is_nil(skin_id) -> skin_id
      _ -> 0  # Default skin
    end

    # Build splash art URL using Riot's CDN
    champion_key = champion.key || champion.name
    "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/#{champion_key}_#{skin_id}.jpg"
  end

  defp get_team_color_class(pick_order_position) do
    case pick_order_position do
      1 -> "bg-blue-500"
      2 -> "bg-red-500" 
      3 -> "bg-green-500"
      4 -> "bg-purple-500"
      5 -> "bg-yellow-500"
      _ -> "bg-gray-500"
    end
  end

  defp get_primary_role(preferred_roles) when is_list(preferred_roles) do
    case preferred_roles do
      [role | _] -> role |> to_string() |> String.upcase()
      [] -> ""
    end
  end

  defp get_primary_role(_), do: ""
end