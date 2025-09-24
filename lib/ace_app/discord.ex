defmodule AceApp.Discord do
  @moduledoc """
  Discord integration service for sending webhook notifications about draft events.
  """

  require Logger
  alias AceApp.Drafts

  @doc """
  Validates a Discord webhook URL by sending a test message.
  Returns {:ok, webhook_info} on success or {:error, reason} on failure.
  """
  def validate_webhook(webhook_url) when is_binary(webhook_url) do
    try do
      case send_webhook(webhook_url, test_embed()) do
        {:ok, _response} ->
          Logger.info("Discord webhook validation successful for URL: #{webhook_url}")
          {:ok, %{validated: true, validated_at: DateTime.utc_now()}}
        
        {:error, reason} ->
          Logger.warning("Discord webhook validation failed for URL: #{webhook_url}, reason: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      ArgumentError -> {:error, "Invalid webhook URL"}
      error -> {:error, "Validation failed: #{Exception.message(error)}"}
    end
  end

  def validate_webhook(_), do: {:error, "Invalid webhook URL"}

  @doc """
  Sends a draft event notification to Discord.
  """
  def notify_draft_event(draft, event_type, data \\ %{}) do
    if draft.discord_webhook_url && draft.discord_webhook_validated && draft.discord_notifications_enabled do
      embed = build_draft_event_embed(draft, event_type, data)
      
      case send_webhook(draft.discord_webhook_url, embed) do
        {:ok, _response} ->
          Logger.info("Discord notification sent for draft #{draft.id}, event: #{event_type}")
          :ok
        
        {:error, reason} ->
          Logger.error("Failed to send Discord notification for draft #{draft.id}, event: #{event_type}, reason: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("Discord: Skipping notification - webhook_url: #{!!draft.discord_webhook_url}, validated: #{draft.discord_webhook_validated}, enabled: #{draft.discord_notifications_enabled}")
      :skip
    end
  end

  @doc """
  Sends a player pick notification to Discord with screenshot from screenshot service.
  """
  def notify_player_pick(draft, pick, player, screenshot_path \\ nil) do

    
    if draft.discord_webhook_url && draft.discord_webhook_validated && draft.discord_notifications_enabled do
      # Capture screenshot if not provided
      screenshot_info = screenshot_path || case AceApp.Screenshot.capture_player_popup_file(player, pick, draft) do
        {:ok, file_path} -> 
          Logger.info("Discord: Screenshot captured successfully: #{file_path}")
          # Verify file actually exists
          if File.exists?(file_path) do
            Logger.info("Discord: Screenshot file confirmed to exist at #{file_path}")
            file_path
          else
            Logger.error("Discord: Screenshot file was created but doesn't exist at #{file_path}")
            nil
          end
        {:error, reason} -> 
          Logger.warning("Discord: Screenshot capture failed: #{inspect(reason)}")
          nil
      end
      
      Logger.info("Discord: Final screenshot_info: #{inspect(screenshot_info)}")
      
      embed = build_pick_embed(draft, pick, player, screenshot_info)
      
      case send_webhook_with_attachment(draft.discord_webhook_url, embed, screenshot_info) do
        {:ok, _response} ->
          Logger.info("Discord pick notification sent for draft #{draft.id}, pick: #{pick.id}")
          :ok
        
        {:error, reason} ->
          Logger.error("Failed to send Discord pick notification for draft #{draft.id}, pick: #{pick.id}, reason: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("Discord: Skipping notification - conditions not met")
      :skip
    end
  end

  # Private functions

  defp send_webhook(webhook_url, embed) do
    body = %{
      embeds: [embed]
    }

    case Req.post(webhook_url, 
                  json: body, 
                  headers: [{"User-Agent", "AceApp-Discord-Bot/1.0"}],
                  receive_timeout: 10_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, :success}
      
      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "HTTP #{status}: #{inspect(error_body)}"}
      
      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp send_webhook_with_attachment(webhook_url, embed, screenshot_path) when is_binary(screenshot_path) do
    if File.exists?(screenshot_path) do
      filename = Path.basename(screenshot_path)
      
      # Update embed to reference the attachment
      embed_with_attachment = Map.put(embed, :image, %{url: "attachment://#{filename}"})
      
      # Try multipart upload - if it fails, fall back to message without image
      try do
        # Use curl command which we know works for Discord multipart uploads
        payload_json = Jason.encode!(%{embeds: [embed_with_attachment]})
        
        curl_args = [
          "-X", "POST", webhook_url,
          "-H", "User-Agent: AceApp-Discord-Bot/1.0",
          "-F", "payload_json=#{payload_json}",
          "-F", "file=@#{screenshot_path}"
        ]
        
        Logger.info("Attempting Discord upload with curl: #{filename}")
        Logger.info("Curl command: curl #{Enum.join(curl_args, " ")}")
        
        case System.cmd("curl", curl_args, stderr_to_stdout: true) do
          {output, 0} ->
            Logger.info("Discord notification sent with image attachment: #{filename}")
            {:ok, :success}
          
          {error_output, _exit_code} ->
            Logger.warning("Discord image upload failed via curl: #{error_output}, sending without image")
            send_webhook(webhook_url, embed)
        end
      rescue
        error ->
          Logger.warning("Discord image upload error (#{inspect(error)}), sending without image")
          send_webhook(webhook_url, embed)
      end
    else
      Logger.warning("Screenshot file not found: #{screenshot_path}, sending without image")
      send_webhook(webhook_url, embed)
    end
  end

  defp send_webhook_with_attachment(webhook_url, embed, _) do
    # No screenshot file, send normal webhook
    send_webhook(webhook_url, embed)
  end

  defp test_embed do
    %{
      title: "🔗 Discord Integration Connected!",
      description: "Your draft is now connected to Discord. You'll receive notifications for:\n\n• Draft started/paused/completed\n• Player picks with champion splash art\n• Important draft events",
      color: 0x5865F2,  # Discord blurple
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      footer: %{
        text: "Discord Integration Test • League Draft Tool",
        icon_url: "https://cdn.discordapp.com/emojis/1234567890123456789.png"  # Optional: Add your app icon
      },
      fields: [
        %{
          name: "✅ Status",
          value: "Connected and ready",
          inline: true
        },
        %{
          name: "🎮 Game",
          value: "League of Legends",
          inline: true
        }
      ]
    }
  end

  defp build_draft_event_embed(draft, event_type, _data) do
    {title, description, color} = case event_type do
      :started ->
        {"🚀 Draft Started!", 
         "**#{draft.name}** has begun! Players can now make their picks.", 
         0x00FF00}  # Green
      
      :paused ->
        {"⏸️ Draft Paused", 
         "**#{draft.name}** has been paused by the organizer.", 
         0xFFFF00}  # Yellow
      
      :resumed ->
        {"▶️ Draft Resumed", 
         "**#{draft.name}** has been resumed. Picks continue!", 
         0x00FF00}  # Green
      
      :completed ->
        {"🏆 Draft Completed!", 
         "**#{draft.name}** has finished! All picks are complete.", 
         0x0099FF}  # Blue
      
      _ ->
        {"📢 Draft Update", 
         "**#{draft.name}** - #{event_type}", 
         0x5865F2}  # Discord blurple
    end

    base_embed = %{
      title: title,
      description: description,
      color: color,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      footer: %{
        text: "#{draft.name} • League Draft Tool"
      }
    }

    # Add additional fields based on event type and data
    fields = case event_type do
      :started ->
        teams = Drafts.list_teams(draft.id)
        team_list = teams
                   |> Enum.with_index(1)
                   |> Enum.map(fn {team, index} -> "#{index}. #{team.name}" end)
                   |> Enum.join("\n")
        
        [%{
          name: "🏆 Teams (Pick Order)",
          value: team_list,
          inline: false
        }]
      
      _ -> []
    end

    Map.put(base_embed, :fields, fields)
  end

  defp build_pick_embed(draft, pick, player, _screenshot_info) do
    team = Drafts.get_team!(pick.team_id)
    
    # Calculate round and pick number for footer
    total_teams = length(Drafts.list_teams(draft.id))
    round_number = div(pick.pick_number - 1, total_teams) + 1
    pick_in_round = rem(pick.pick_number - 1, total_teams) + 1
    
    embed = %{
      title: "🎯 Player Picked!",
      description: "**#{team.name}** has picked **#{player.display_name}**!",
      color: 0xC89B3C,  # Gold color for picks
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      footer: %{
        text: "#{draft.name} • Round #{round_number} • Pick #{pick.pick_number}"
      },
      fields: [
        %{
          name: "🏆 Team",
          value: team.name,
          inline: true
        },
        %{
          name: "👤 Player",
          value: player.display_name,
          inline: true
        },
        %{
          name: "📊 Position",
          value: "Round #{round_number}, Pick #{pick_in_round}",
          inline: true
        }
      ]
    }

    # Add champion image if player has a champion assigned
    embed = if player.champion_id do
      champion = AceApp.LoL.get_champion!(player.champion_id)
      
      # Get skin splash URL using existing Community Dragon logic
      image_url = if player.preferred_skin_id do
        case AceApp.LoL.get_champion_skin(player.champion_id, player.preferred_skin_id) do
          skin when not is_nil(skin) ->
            AceApp.LoL.get_skin_splash_url(champion, skin)
          _ ->
            champion.image_url
        end
      else
        champion.image_url
      end
      
      # Just add the image, no text fields
      Map.put(embed, :image, %{url: image_url})
    else
      embed
    end

    embed
  end
end