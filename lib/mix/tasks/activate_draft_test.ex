defmodule Mix.Tasks.ActivateDraftTest do
  @moduledoc """
  Mix task to activate draft 11 and test Discord notifications.
  
  Usage: mix activate_draft_test
  """
  use Mix.Task

  @shortdoc "Activate draft 11 and test Discord notifications"

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("=== ACTIVATING DRAFT 11 FOR DISCORD TEST ===")
    
    try do
      # Find draft 11
      draft = AceApp.Drafts.get_draft!(11)
      IO.puts("Found draft 11: #{draft.name}")
      IO.puts("Current status: #{draft.status}")
      
      # Try to start the draft
      IO.puts("Attempting to start draft...")
      case AceApp.Drafts.start_draft(draft.id) do
        {:ok, updated_draft} ->
          IO.puts("Draft started successfully! New status: #{updated_draft.status}")
          
          # Wait a moment then try to make a pick
          :timer.sleep(1000)
          
          # Get available players and teams
          players = AceApp.Drafts.list_players(draft.id)
          teams = AceApp.Drafts.list_teams(draft.id)
          
          if length(players) > 0 and length(teams) > 0 do
            player = Enum.at(players, 0)
            team = Enum.at(teams, 0)
            
            IO.puts("Testing pick with player: #{player.display_name}, team: #{team.name}")
            
            # Check queue state before pick
            queue_state = AceApp.DiscordQueue.get_state()
            IO.puts("Queue state before pick: processing=#{queue_state.processing}, queue_size=#{:queue.len(queue_state.queue)}")
            
            # Make a pick
            case AceApp.Drafts.make_pick(draft.id, player.id, team.id, 1, :top) do
              {:ok, pick} ->
                IO.puts("Pick made successfully! Pick ID: #{pick.id}")
                
                # Wait and check queue
                :timer.sleep(2000)
                new_queue_state = AceApp.DiscordQueue.get_state()
                queue_size = :queue.len(new_queue_state.queue)
                
                IO.puts("=== DISCORD QUEUE STATUS AFTER PICK ===")
                IO.puts("Queue processing: #{new_queue_state.processing}")
                IO.puts("Items in queue: #{queue_size}")
                
                if queue_size > 0 do
                  IO.puts("SUCCESS: Discord notification was enqueued!")
                  IO.puts("Queue should be processing the notification...")
                  
                  # Wait longer and check again
                  :timer.sleep(3000)
                  final_state = AceApp.DiscordQueue.get_state()
                  final_queue_size = :queue.len(final_state.queue)
                  
                  IO.puts("=== FINAL QUEUE STATUS ===")
                  IO.puts("Queue processing: #{final_state.processing}")
                  IO.puts("Items remaining in queue: #{final_queue_size}")
                  
                  if final_queue_size < queue_size do
                    IO.puts("SUCCESS: Queue processed #{queue_size - final_queue_size} item(s)!")
                  else
                    IO.puts("WARNING: Queue did not process any items")
                  end
                else
                  IO.puts("WARNING: No Discord notification was enqueued")
                end
                
              {:error, reason} ->
                IO.puts("Failed to make pick: #{inspect(reason)}")
            end
          end
          
        {:error, reason} ->
          IO.puts("Failed to start draft: #{inspect(reason)}")
          
          # Try alternative approach - use preview functionality
          IO.puts("Trying preview functionality instead...")
          
          players = AceApp.Drafts.list_players(draft.id)
          if length(players) > 0 do
            player = Enum.at(players, 0)
            IO.puts("Testing preview pick with player: #{player.display_name}")
            
            # Check if there's a preview_pick function or similar
            # This might be in a different module or have a different name
            try do
              # Try to find and use preview functionality
              IO.puts("Looking for preview functionality...")
              
              # Check queue before
              queue_state = AceApp.DiscordQueue.get_state()
              IO.puts("Queue state before preview: processing=#{queue_state.processing}, queue_size=#{:queue.len(queue_state.queue)}")
              
              # Try to enqueue a Discord notification directly
              teams = AceApp.Drafts.list_teams(draft.id)
              if length(teams) > 0 do
                team = Enum.at(teams, 0)
                
                # Create a mock pick for testing
                mock_pick = %{
                  id: 999,
                  player_id: player.id,
                  team_id: team.id,
                  champion_id: 1,
                  role: :top,
                  pick_number: 1
                }
                
                IO.puts("Enqueueing Discord notification directly...")
                AceApp.DiscordQueue.enqueue_pick_notification(draft, mock_pick, player)
                
                # Check queue after
                :timer.sleep(2000)
                new_queue_state = AceApp.DiscordQueue.get_state()
                queue_size = :queue.len(new_queue_state.queue)
                
                IO.puts("Queue state after enqueue: processing=#{new_queue_state.processing}, queue_size=#{queue_size}")
                
                if queue_size > 0 do
                  IO.puts("SUCCESS: Discord notification was enqueued directly!")
                else
                  IO.puts("Queue was processed already or notification failed")
                end
              end
              
            rescue
              preview_error ->
                IO.puts("Preview test failed: #{inspect(preview_error)}")
            end
          end
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
    end
    
    IO.puts("=== TEST COMPLETED ===")
  end
end