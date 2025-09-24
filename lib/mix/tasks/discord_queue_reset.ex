defmodule Mix.Tasks.DiscordQueueReset do
  @moduledoc """
  Mix task to reset Discord queue processing state.
  
  Usage: mix discord_queue_reset
  """
  use Mix.Task

  @shortdoc "Reset Discord queue processing state"

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("=== DISCORD QUEUE RESET TASK ===")
    
    try do
      # Get current queue state
      IO.puts("Getting Discord queue state...")
      state = AceApp.DiscordQueue.get_state()
      IO.puts("Current queue state: #{inspect(state)}")
      
      queue_size = :queue.len(state.queue)
      IO.puts("Items in queue: #{queue_size}")
      
      if state.processing do
        IO.puts("Queue is stuck in processing state, resetting...")
        AceApp.DiscordQueue.reset_processing()
        :timer.sleep(2000)
        
        new_state = AceApp.DiscordQueue.get_state()
        IO.puts("Queue state after reset: #{inspect(new_state)}")
        
        if :queue.len(new_state.queue) > 0 do
          IO.puts("Queue should now process #{:queue.len(new_state.queue)} items...")
        end
      else
        IO.puts("Queue is not stuck, processing: #{state.processing}")
        
        if queue_size > 0 do
          IO.puts("Queue has items but is not processing. This might indicate an issue.")
          IO.puts("Triggering queue processing...")
          AceApp.DiscordQueue.reset_processing()
        end
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
    end
    
    IO.puts("=== TASK COMPLETED ===")
  end
end