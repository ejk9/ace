defmodule Mix.Tasks.TestDiscordAttachment do
  @moduledoc """
  Mix task to test Discord notification with file attachment.
  
  Usage: mix test_discord_attachment
  """
  use Mix.Task

  @shortdoc "Test Discord notification with file attachment"

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("=== TESTING DISCORD FILE ATTACHMENT ===")
    
    try do
      # Find draft 11
      draft = AceApp.Drafts.get_draft!(11)
      IO.puts("Found draft 11: #{draft.name}")
      IO.puts("Discord webhook URL: #{String.slice(draft.discord_webhook_url, 0, 50)}...")
      
      # Get a player for testing
      players = AceApp.Drafts.list_players(draft.id)
      teams = AceApp.Drafts.list_teams(draft.id)
      
      if length(players) > 0 and length(teams) > 0 do
        player = Enum.at(players, 0)
        team = Enum.at(teams, 0)
        
        IO.puts("Testing with player: #{player.display_name}")
        
        # Create a mock pick for testing
        mock_pick = %{
          id: 9999,
          player_id: player.id,
          team_id: team.id,
          champion_id: 1, # Aatrox
          role: :top,
          pick_number: 1
        }
        
        IO.puts("Creating test notification...")
        AceApp.DiscordQueue.enqueue_pick_notification(draft, mock_pick, player)
        
        # Wait and monitor the process
        IO.puts("Monitoring Discord notification process...")
        
        # Check every second for 10 seconds
        Enum.each(1..10, fn i ->
          :timer.sleep(1000)
          state = AceApp.DiscordQueue.get_state()
          queue_size = :queue.len(state.queue)
          IO.puts("#{i}s: processing=#{state.processing}, queue_size=#{queue_size}")
          
          if not state.processing and queue_size == 0 do
            IO.puts("✅ Notification completed!")
            throw(:completed)
          end
        end)
        
        # Final check
        final_state = AceApp.DiscordQueue.get_state()
        if final_state.processing do
          IO.puts("⚠️  Still processing after 10 seconds")
        else
          IO.puts("✅ Test completed")
        end
        
      else
        IO.puts("No players or teams available for testing")
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
    catch
      :completed ->
        IO.puts("✅ Test completed successfully")
    end
    
    IO.puts("=== TEST FINISHED ===")
    IO.puts("Check your Discord channel to see if the message appeared with an image attachment.")
  end
end