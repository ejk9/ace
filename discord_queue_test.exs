#!/usr/bin/env elixir

# Script to test Discord queue functionality
# Run this with: elixir discord_queue_test.exs

IO.puts("=== DISCORD QUEUE TEST SCRIPT ===")
IO.puts("Connecting to running Phoenix application...")

# This script should be run when Phoenix is already running
# It will try to connect to the running application modules

defmodule DiscordQueueTest do
  def run do
    try do
      # Check if AceApp modules are available
      IO.puts("Testing module availability...")
      
      # Get current queue state
      IO.puts("Getting Discord queue state...")
      state = AceApp.DiscordQueue.get_state()
      IO.puts("Current queue state: #{inspect(state)}")
      
      # Reset processing if stuck
      if state.processing do
        IO.puts("Queue is stuck in processing state, resetting...")
        AceApp.DiscordQueue.reset_processing()
        :timer.sleep(1000)
        
        new_state = AceApp.DiscordQueue.get_state()
        IO.puts("Queue state after reset: #{inspect(new_state)}")
      else
        IO.puts("Queue is not stuck, processing: #{state.processing}")
      end
      
      # Check if there are items in queue
      queue_size = :queue.len(state.queue)
      IO.puts("Items in queue: #{queue_size}")
      
      if queue_size > 0 do
        IO.puts("Queue has #{queue_size} items waiting to be processed")
        IO.puts("Items should start processing now...")
      else
        IO.puts("Queue is empty")
      end
      
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
        IO.puts("Make sure Phoenix server is running with: mix phx.server")
    end
  end
end

DiscordQueueTest.run()