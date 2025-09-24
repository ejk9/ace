defmodule Mix.Tasks.TestTwoPicks do
  @moduledoc """
  Mix task to test Discord notifications with two sequential picks.
  
  Usage: mix test_two_picks
  """
  use Mix.Task

  @shortdoc "Test Discord notifications with two sequential picks"

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("=== TESTING TWO SEQUENTIAL DISCORD PICKS ===")
    
    try do
      # Find draft 11
      draft = AceApp.Drafts.get_draft!(11)
      IO.puts("Found draft 11: #{draft.name}")
      
      # Get available players and teams
      players = AceApp.Drafts.list_players(draft.id)
      teams = AceApp.Drafts.list_teams(draft.id)
      
      if length(players) >= 2 and length(teams) >= 2 do
        player1 = Enum.at(players, 0)
        player2 = Enum.at(players, 1)
        team1 = Enum.at(teams, 0)
        team2 = Enum.at(teams, 1)
        
        IO.puts("Testing with:")
        IO.puts("  Pick 1: #{player1.display_name} (#{team1.name})")
        IO.puts("  Pick 2: #{player2.display_name} (#{team2.name})")
        
        # Reset queue before testing
        IO.puts("\n=== RESETTING QUEUE BEFORE TEST ===")
        AceApp.DiscordQueue.reset_processing()
        initial_state = AceApp.DiscordQueue.get_state()
        IO.puts("Initial queue state: processing=#{initial_state.processing}, queue_size=#{:queue.len(initial_state.queue)}")
        
        # PICK 1
        IO.puts("\n=== MAKING PICK 1 ===")
        mock_pick1 = %{
          id: 1001,
          player_id: player1.id,
          team_id: team1.id,
          champion_id: 1, # Aatrox
          role: :top,
          pick_number: 1
        }
        
        IO.puts("Enqueueing pick 1...")
        AceApp.DiscordQueue.enqueue_pick_notification(draft, mock_pick1, player1)
        
        # Wait and check queue after pick 1
        :timer.sleep(3000)
        state_after_pick1 = AceApp.DiscordQueue.get_state()
        queue_size_1 = :queue.len(state_after_pick1.queue)
        IO.puts("After pick 1: processing=#{state_after_pick1.processing}, queue_size=#{queue_size_1}")
        
        if state_after_pick1.processing do
          IO.puts("⚠️  WARNING: Queue still processing after pick 1")
          # Wait longer
          :timer.sleep(5000)
          state_after_wait = AceApp.DiscordQueue.get_state()
          IO.puts("After waiting: processing=#{state_after_wait.processing}, queue_size=#{:queue.len(state_after_wait.queue)}")
        else
          IO.puts("✅ Pick 1 completed successfully")
        end
        
        # PICK 2
        IO.puts("\n=== MAKING PICK 2 ===")
        mock_pick2 = %{
          id: 1002,
          player_id: player2.id,
          team_id: team2.id,
          champion_id: 2, # Ahri
          role: :mid,
          pick_number: 2
        }
        
        IO.puts("Enqueueing pick 2...")
        AceApp.DiscordQueue.enqueue_pick_notification(draft, mock_pick2, player2)
        
        # Check queue immediately after pick 2
        immediate_state = AceApp.DiscordQueue.get_state()
        IO.puts("Immediately after pick 2: processing=#{immediate_state.processing}, queue_size=#{:queue.len(immediate_state.queue)}")
        
        # Wait and check queue after pick 2
        :timer.sleep(3000)
        state_after_pick2 = AceApp.DiscordQueue.get_state()
        queue_size_2 = :queue.len(state_after_pick2.queue)
        IO.puts("After pick 2: processing=#{state_after_pick2.processing}, queue_size=#{queue_size_2}")
        
        if state_after_pick2.processing do
          IO.puts("⚠️  WARNING: Queue still processing after pick 2")
          # Wait longer
          :timer.sleep(5000)
          final_state = AceApp.DiscordQueue.get_state()
          IO.puts("Final state: processing=#{final_state.processing}, queue_size=#{:queue.len(final_state.queue)}")
          
          if final_state.processing do
            IO.puts("🚨 ERROR: Queue is stuck in processing state!")
            IO.puts("Attempting to reset...")
            AceApp.DiscordQueue.reset_processing()
            
            # Check after reset
            :timer.sleep(2000)
            reset_state = AceApp.DiscordQueue.get_state()
            IO.puts("After reset: processing=#{reset_state.processing}, queue_size=#{:queue.len(reset_state.queue)}")
          end
        else
          IO.puts("✅ Pick 2 completed successfully")
        end
        
        IO.puts("\n=== TEST SUMMARY ===")
        final_check = AceApp.DiscordQueue.get_state()
        IO.puts("Final queue state: processing=#{final_check.processing}, queue_size=#{:queue.len(final_check.queue)}")
        
        if :queue.len(final_check.queue) == 0 and not final_check.processing do
          IO.puts("✅ SUCCESS: Both picks processed successfully")
        else
          IO.puts("❌ FAILURE: Queue issues detected")
          IO.puts("   - Queue stuck: #{final_check.processing}")
          IO.puts("   - Items remaining: #{:queue.len(final_check.queue)}")
        end
        
      else
        IO.puts("Not enough players or teams for testing")
        IO.puts("Players: #{length(players)}, Teams: #{length(teams)}")
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
    end
    
    IO.puts("=== TEST COMPLETED ===")
  end
end