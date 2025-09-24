defmodule AceApp.DiscordQueue do
  @moduledoc """
  Sequential Discord notification queue to ensure messages are sent in order.
  Prevents race conditions when multiple picks happen quickly.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Queue a Discord notification to be sent sequentially.
  """
  def enqueue_notification(draft, event_type, extra_data \\ nil) do
    GenServer.cast(__MODULE__, {:enqueue, draft, event_type, extra_data})
  end

  @doc """
  Queue a player pick notification with screenshot.
  """
  def enqueue_pick_notification(draft, pick, player) do
    # Debug: Check current state before enqueueing
    try do
      state = GenServer.call(__MODULE__, :get_state, 1000)
      IO.puts("=== DISCORD QUEUE STATE CHECK ===")
      IO.puts("Current queue state before enqueue: #{inspect(state)}")
    catch
      :exit, {:timeout, _} ->
        IO.puts("=== DISCORD QUEUE TIMEOUT ===")
        IO.puts("GenServer call timed out - queue might be stuck")
      error ->
        IO.puts("=== DISCORD QUEUE ERROR ===")
        IO.puts("Error getting state: #{inspect(error)}")
    end
    
    GenServer.cast(__MODULE__, {:enqueue_pick, draft, pick, player})
  end
  
  @doc """
  Get current queue state for debugging.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  @doc """
  Reset queue processing state if it gets stuck.
  """
  def reset_processing do
    GenServer.cast(__MODULE__, :reset_processing)
  end

  # Server Implementation

  @impl true
  def init([]) do
    IO.puts("=== DISCORD QUEUE STARTING ===")
    Logger.info("Discord notification queue started")
    initial_state = %{queue: :queue.new(), processing: false}
    IO.puts("Discord queue initial state: #{inspect(initial_state)}")
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:enqueue, draft, event_type, extra_data}, state) do
    item = {:draft_event, draft, event_type, extra_data}
    new_queue = :queue.in(item, state.queue)
    new_state = %{state | queue: new_queue}
    
    Logger.debug("Enqueued Discord draft event: #{event_type} for draft #{draft.id}")
    
    # Process queue if not already processing
    if not state.processing do
      send(self(), :process_queue)
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:enqueue_pick, draft, pick, player}, state) do
    item = {:pick_notification, draft, pick, player}
    new_queue = :queue.in(item, state.queue)
    new_state = %{state | queue: new_queue}
    
    IO.puts("=== DISCORD QUEUE ENQUEUE ===")
    IO.puts("Discord Queue: Enqueued pick notification for pick #{pick.id}, player #{player.display_name}, draft #{draft.id}")
    IO.puts("Queue processing: #{state.processing}")
    IO.puts("Sending :process_queue message...")
    
    Logger.info("Discord Queue: Enqueued pick notification for pick #{pick.id}, player #{player.display_name}, draft #{draft.id}")
    
    # Process queue if not already processing
    if not state.processing do
      send(self(), :process_queue)
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset_processing, state) do
    IO.puts("=== DISCORD QUEUE RESET ===")
    IO.puts("Resetting Discord queue processing state from #{state.processing} to false")
    Logger.info("Resetting Discord queue processing state")
    
    new_state = %{state | processing: false}
    
    # Trigger processing if there are items in queue
    if not :queue.is_empty(state.queue) do
      IO.puts("Queue has items, sending :process_queue")
      send(self(), :process_queue)
    else
      IO.puts("Queue is empty after reset")
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:process_queue, %{queue: queue, processing: false} = state) do
    IO.puts("=== DISCORD QUEUE PROCESSING ===")
    IO.puts("Processing queue, current processing: #{state.processing}")
    
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        IO.puts("Found item in queue, processing: #{inspect(item)}")
        Logger.debug("Processing Discord notification from queue")
        
        # Mark as processing and process the item
        IO.puts("Setting processing: true")
        new_state = %{state | queue: new_queue, processing: true}
        
        # Process in a separate task to avoid blocking the queue
        parent = self()
        task_pid = Task.start(fn ->
          try do
            result = process_item(item)
            IO.puts("=== DISCORD TASK COMPLETED ===")
            IO.puts("Discord notification task completed: #{inspect(result)}")
            Logger.debug("Discord notification task completed: #{inspect(result)}")
            send(parent, :item_completed)
          catch
            error ->
              IO.puts("=== DISCORD TASK ERROR ===")
              IO.puts("Error: #{inspect(error)}")
              Logger.error("Discord notification failed: #{inspect(error)}")
              send(parent, :item_completed)
          after
            # Always send completion message even if something goes wrong
            send(parent, :item_completed)
          end
        end)
        
        # Set a timeout to ensure we don't get stuck forever
        Process.send_after(self(), {:task_timeout, task_pid}, 30_000)
        
        {:noreply, new_state}
        
      {:empty, _} ->
        # Queue is empty, nothing to process
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:process_queue, %{processing: true} = state) do
    # Already processing, ignore
    IO.puts("=== DISCORD QUEUE ALREADY PROCESSING ===")
    IO.puts("Ignoring :process_queue because processing: true")
    {:noreply, state}
  end

  @impl true
  def handle_info(:item_completed, state) do
    IO.puts("=== DISCORD QUEUE ITEM COMPLETED ===")
    IO.puts("Discord notification completed, checking for more items")
    IO.puts("Queue empty: #{:queue.is_empty(state.queue)}")
    
    Logger.debug("Discord notification completed, checking for more items")
    new_state = %{state | processing: false}
    
    # Check if there are more items to process
    if not :queue.is_empty(state.queue) do
      IO.puts("More items in queue, sending :process_queue")
      send(self(), :process_queue)
    else
      IO.puts("Queue is empty, done processing")
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:task_timeout, task_pid}, %{processing: true} = state) do
    IO.puts("=== DISCORD QUEUE TASK TIMEOUT ===")
    IO.puts("Task #{inspect(task_pid)} timed out after 30 seconds")
    Logger.warning("Discord notification task timed out")
    
    # Kill the task if it's still running
    if Process.alive?(task_pid) do
      Process.exit(task_pid, :kill)
    end
    
    # Reset processing state and continue with queue
    new_state = %{state | processing: false}
    
    if not :queue.is_empty(state.queue) do
      send(self(), :process_queue)
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:task_timeout, _task_pid}, state) do
    # Timeout for task that's not currently processing, ignore
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Handle task completion messages that we don't explicitly catch
    Logger.debug("Discord queue received task completion: #{inspect(result)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Handle task process down messages
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    IO.puts("=== DISCORD QUEUE UNEXPECTED MESSAGE ===")
    IO.puts("Received unexpected message: #{inspect(msg)}")
    IO.puts("Current state: #{inspect(state)}")
    Logger.warning("Discord queue received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helper functions

  defp process_item({:draft_event, draft, event_type, _extra_data}) do
    Logger.info("Sending Discord draft event: #{event_type} for draft #{draft.id}")
    AceApp.Discord.notify_draft_event(draft, event_type)
  end

  defp process_item({:pick_notification, draft, pick, player}) do
    IO.puts("=== DISCORD QUEUE PROCESSING ITEM ===")
    IO.puts("Discord Queue: Processing pick notification for pick #{pick.id}, player #{player.display_name}")
    
    Logger.info("Discord Queue: Processing pick notification for pick #{pick.id}, player #{player.display_name}")
    
    # Check if player has champion assigned (affects screenshot)
    champion_info = if player.champion_id do
      "with champion #{player.champion_id}"
    else
      "without champion assigned"
    end
    
    IO.puts("Discord Queue: Player #{player.display_name} #{champion_info}")
    Logger.info("Discord Queue: Player #{player.display_name} #{champion_info}")
    
    IO.puts("Calling AceApp.Discord.notify_player_pick...")
    result = AceApp.Discord.notify_player_pick(draft, pick, player)
    IO.puts("Discord notification result: #{inspect(result)}")
    Logger.info("Discord Queue: Pick notification result: #{inspect(result)}")
    result
  end
end