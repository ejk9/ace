defmodule Mix.Tasks.TestDiscordPick do
  @moduledoc """
  Mix task to test Discord notifications by making a pick on draft 11.
  
  Usage: mix test_discord_pick
  """
  use Mix.Task

  @shortdoc "Test Discord notifications by making a pick"

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("=== TESTING DISCORD PICK NOTIFICATION ===")
    
    try do
      # Find draft 11
      draft = AceApp.Drafts.get_draft!(11)
      IO.puts("Found draft 11: #{draft.name}")
      IO.puts("Discord webhook URL configured: #{!!draft.discord_webhook_url}")
      IO.puts("Discord notifications enabled: #{draft.discord_notifications_enabled}")
      IO.puts("Discord webhook validated: #{draft.discord_webhook_validated}")
      
      # Get available players
      players = AceApp.Drafts.list_players(draft.id)
      IO.puts("Available players: #{length(players)}")
      
      if length(players) > 0 do
        player = Enum.at(players, 0)
        IO.puts("Testing with player: #{player.display_name}")
        
        # Check if there are teams
        teams = AceApp.Drafts.list_teams(draft.id)
        IO.puts("Teams available: #{length(teams)}")
        
        if length(teams) > 0 do
          team = Enum.at(teams, 0)
          IO.puts("Testing with team: #{team.name}")
          
          # Check queue state before making pick
          queue_state = AceApp.DiscordQueue.get_state()
          IO.puts("Queue state before pick: #{inspect(queue_state)}")
          
          # Try to make a pick using the preview functionality
          IO.puts("Attempting to make a preview pick...")
          
          # Create a mock pick data
          pick_data = %{
            player_id: player.id,
            team_id: team.id,
            pick_number: 1,
            champion_id: 1, # Aatrox
            role: :top
          }
          
          # Use the preview pick functionality
          case AceApp.Drafts.make_pick(draft.id, pick_data.player_id, pick_data.team_id, pick_data.champion_id, pick_data.role) do
            {:ok, pick} ->
              IO.puts("Pick made successfully: #{inspect(pick)}")
              
              # Check queue state after pick
              :timer.sleep(1000)
              new_queue_state = AceApp.DiscordQueue.get_state()
              IO.puts("Queue state after pick: #{inspect(new_queue_state)}")
              
              queue_size = :queue.len(new_queue_state.queue)
              IO.puts("Items in queue after pick: #{queue_size}")
              
              if queue_size > 0 do
                IO.puts("Discord notification was enqueued!")
                IO.puts("Processing state: #{new_queue_state.processing}")
              else
                IO.puts("No Discord notification was enqueued")
              end
              
            {:error, reason} ->
              IO.puts("Failed to make pick: #{inspect(reason)}")
          end
          
        else
          IO.puts("No teams available in draft 11")
        end
      else
        IO.puts("No players available in draft 11")
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
        
        # Try to list all drafts to see what's available
        try do
          drafts = AceApp.Drafts.list_drafts()
          IO.puts("Available drafts:")
          for draft <- drafts do
            IO.puts("  ID: #{draft.id}, Name: #{draft.name}, Status: #{draft.status}")
          end
        rescue
          list_error ->
            IO.puts("Could not list drafts: #{inspect(list_error)}")
        end
    end
    
    IO.puts("=== TEST COMPLETED ===")
  end
end