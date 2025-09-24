defmodule AceApp.Drafts.DraftTimer do
  @moduledoc """
  GenServer that manages countdown timers for draft picks.
  
  Each active draft gets its own timer process that handles:
  - Countdown timing for team picks
  - Real-time broadcasts to all connected clients
  - Timer state persistence for recovery
  - Auto-expiration handling
  """
  
  use GenServer
  require Logger
  
  alias AceApp.Drafts
  
  @tick_interval 1000  # 1 second
  
  # Timer state structure
  defstruct [
    :draft_id,
    :status,           # :stopped | :running | :paused | :expired
    :remaining_seconds,
    :total_seconds,
    :current_team_id,
    :deadline,         # DateTime when timer expires
    :tick_ref          # Timer reference for periodic ticks
  ]
  
  ## Client API
  
  @doc """
  Starts a timer process for a draft.
  """
  def start_link(draft_id) do
    GenServer.start_link(__MODULE__, draft_id, name: via_tuple(draft_id))
  end
  
  @doc """
  Starts the countdown timer for a team's pick.
  """
  def start_timer(draft_id, team_id, duration_seconds) do
    GenServer.call(via_tuple(draft_id), {:start_timer, team_id, duration_seconds})
  end
  
  @doc """
  Pauses the current timer.
  """
  def pause_timer(draft_id) do
    GenServer.call(via_tuple(draft_id), :pause_timer)
  end
  
  @doc """
  Resumes a paused timer.
  """
  def resume_timer(draft_id) do
    GenServer.call(via_tuple(draft_id), :resume_timer)
  end
  
  @doc """
  Stops the timer completely.
  """
  def stop_timer(draft_id) do
    GenServer.call(via_tuple(draft_id), :stop_timer)
  end
  
  @doc """
  Gets the current timer state.
  """
  def get_state(draft_id) do
    case GenServer.whereis(via_tuple(draft_id)) do
      nil -> {:error, :timer_not_found}
      _pid -> GenServer.call(via_tuple(draft_id), :get_state)
    end
  end
  
  @doc """
  Checks if a timer process exists for the given draft.
  """
  def timer_exists?(draft_id) do
    case GenServer.whereis(via_tuple(draft_id)) do
      nil -> false
      _pid -> true
    end
  end
  
  ## GenServer Callbacks
  
  @impl true
  def init(draft_id) do
    Logger.info("Starting DraftTimer for draft #{draft_id}")
    
    state = %__MODULE__{
      draft_id: draft_id,
      status: :stopped,
      remaining_seconds: 0,
      total_seconds: 0,
      current_team_id: nil,
      deadline: nil,
      tick_ref: nil
    }
    
    # Try to recover timer state from database
    case recover_timer_state(draft_id) do
      {:ok, recovered_state} ->
        Logger.info("Recovered timer state for draft #{draft_id}")
        {:ok, recovered_state}
      
      {:error, _reason} ->
        {:ok, state}
    end
  end
  
  @impl true
  def handle_call({:start_timer, team_id, duration_seconds}, _from, state) do
    Logger.info("Starting timer for draft #{state.draft_id}, team #{team_id}, duration #{duration_seconds}s")
    
    # Cancel any existing timer
    cancel_tick_timer(state.tick_ref)
    
    # Calculate deadline
    deadline = DateTime.add(DateTime.utc_now(), duration_seconds, :second)
    
    # Start the tick timer
    tick_ref = schedule_tick()
    
    new_state = %{state |
      status: :running,
      remaining_seconds: duration_seconds,
      total_seconds: duration_seconds,
      current_team_id: team_id,
      deadline: deadline,
      tick_ref: tick_ref
    }
    
    # Persist timer state
    persist_timer_state(new_state)
    
    # Broadcast initial timer state
    broadcast_timer_state(new_state)
    
    # Log the timer start event
    Drafts.log_draft_event(state.draft_id, "timer_started", %{
      team_id: team_id,
      duration_seconds: duration_seconds,
      deadline: deadline
    })
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:pause_timer, _from, %{status: :running} = state) do
    Logger.info("Pausing timer for draft #{state.draft_id}")
    
    # Cancel the tick timer
    cancel_tick_timer(state.tick_ref)
    
    new_state = %{state |
      status: :paused,
      tick_ref: nil
    }
    
    # Persist the paused state
    persist_timer_state(new_state)
    
    # Broadcast paused state
    broadcast_timer_state(new_state)
    
    # Log the pause event
    Drafts.log_draft_event(state.draft_id, "timer_paused", %{
      remaining_seconds: state.remaining_seconds,
      team_id: state.current_team_id
    })
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:pause_timer, _from, state) do
    # Timer not running, nothing to pause
    {:reply, {:error, :timer_not_running}, state}
  end
  
  @impl true
  def handle_call(:resume_timer, _from, %{status: :paused} = state) do
    Logger.info("Resuming timer for draft #{state.draft_id}")
    
    # Recalculate deadline based on remaining time
    deadline = DateTime.add(DateTime.utc_now(), state.remaining_seconds, :second)
    
    # Start the tick timer
    tick_ref = schedule_tick()
    
    new_state = %{state |
      status: :running,
      deadline: deadline,
      tick_ref: tick_ref
    }
    
    # Persist the resumed state
    persist_timer_state(new_state)
    
    # Broadcast resumed state
    broadcast_timer_state(new_state)
    
    # Log the resume event
    Drafts.log_draft_event(state.draft_id, "timer_resumed", %{
      remaining_seconds: state.remaining_seconds,
      team_id: state.current_team_id
    })
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:resume_timer, _from, state) do
    # Timer not paused, nothing to resume
    {:reply, {:error, :timer_not_paused}, state}
  end
  
  @impl true
  def handle_call(:stop_timer, _from, state) do
    Logger.info("Stopping timer for draft #{state.draft_id}")
    
    # Cancel any existing timer
    cancel_tick_timer(state.tick_ref)
    
    new_state = %{state |
      status: :stopped,
      remaining_seconds: 0,
      current_team_id: nil,
      deadline: nil,
      tick_ref: nil
    }
    
    # Clear persisted timer state
    clear_timer_state(state.draft_id)
    
    # Broadcast stopped state
    broadcast_timer_state(new_state)
    
    # Log the stop event
    Drafts.log_draft_event(state.draft_id, "timer_stopped", %{})
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    timer_state = %{
      status: state.status,
      remaining_seconds: state.remaining_seconds,
      total_seconds: state.total_seconds,
      current_team_id: state.current_team_id,
      deadline: state.deadline
    }
    
    {:reply, {:ok, timer_state}, state}
  end
  
  @impl true
  def handle_info(:tick, %{status: :running} = state) do
    now = DateTime.utc_now()
    
    cond do
      # Timer expired
      DateTime.compare(now, state.deadline) != :lt ->
        handle_timer_expiration(state)
      
      # Timer still running, update remaining time
      true ->
        remaining_seconds = DateTime.diff(state.deadline, now, :second)
        
        new_state = %{state | remaining_seconds: max(0, remaining_seconds)}
        
        # Persist updated state (for recovery)
        persist_timer_state(new_state)
        
        # Only broadcast on important thresholds, not every second
        should_broadcast = cond do
          # Warning thresholds (30s, 10s, 5s)
          remaining_seconds in [30, 10, 5] ->
            broadcast_timer_warning(new_state, remaining_seconds)
            true
          
          # Sync broadcast every 15 seconds to correct client drift
          rem(remaining_seconds, 15) == 0 and remaining_seconds > 0 ->
            true
          
          # Don't broadcast every second
          true ->
            false
        end
        
        if should_broadcast do
          broadcast_timer_sync(new_state)
        end
        
        # Schedule next tick
        tick_ref = schedule_tick()
        {:noreply, %{new_state | tick_ref: tick_ref}}
    end
  end
  
  @impl true
  def handle_info(:tick, state) do
    # Timer not running, ignore tick
    {:noreply, state}
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("DraftTimer terminating for draft #{state.draft_id}, reason: #{inspect(reason)}")
    
    # Cancel any pending timer
    cancel_tick_timer(state.tick_ref)
    
    # Persist final state for recovery
    if state.status in [:running, :paused] do
      persist_timer_state(state)
    end
    
    :ok
  end
  
  ## Private Functions
  
  defp via_tuple(draft_id) do
    {:via, Registry, {AceApp.DraftTimerRegistry, draft_id}}
  end
  
  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
  
  defp cancel_tick_timer(nil), do: :ok
  defp cancel_tick_timer(tick_ref) do
    Process.cancel_timer(tick_ref)
    :ok
  end
  
  defp handle_timer_expiration(state) do
    Logger.info("Timer expired for draft #{state.draft_id}, team #{state.current_team_id}")
    
    # Cancel the tick timer
    cancel_tick_timer(state.tick_ref)
    
    new_state = %{state |
      status: :expired,
      remaining_seconds: 0,
      tick_ref: nil
    }
    
    # Persist expired state
    persist_timer_state(new_state)
    
    # Broadcast expiration
    broadcast_timer_expiration(new_state)
    
    # Log the expiration event
    Drafts.log_draft_event(state.draft_id, "timer_expired", %{
      team_id: state.current_team_id,
      total_seconds: state.total_seconds
    })
    
    {:noreply, new_state}
  end
  
  defp broadcast_timer_state(state) do
    Phoenix.PubSub.broadcast(
      AceApp.PubSub,
      "draft:#{state.draft_id}",
      {:timer_state, %{
        status: state.status,
        remaining_seconds: state.remaining_seconds,
        total_seconds: state.total_seconds,
        current_team_id: state.current_team_id,
        deadline: state.deadline,
        server_time: DateTime.utc_now()
      }}
    )
  end
  
  # New function for sync broadcasts (less frequent)
  defp broadcast_timer_sync(state) do
    Phoenix.PubSub.broadcast(
      AceApp.PubSub,
      "draft:#{state.draft_id}",
      {:timer_sync, %{
        remaining_seconds: state.remaining_seconds,
        deadline: state.deadline,
        server_time: DateTime.utc_now()
      }}
    )
  end
  
  defp broadcast_timer_warning(state, seconds_remaining) do
    Phoenix.PubSub.broadcast(
      AceApp.PubSub,
      "draft:#{state.draft_id}",
      {:timer_warning, %{
        seconds_remaining: seconds_remaining,
        team_id: state.current_team_id
      }}
    )
  end
  
  defp broadcast_timer_expiration(state) do
    Phoenix.PubSub.broadcast(
      AceApp.PubSub,
      "draft:#{state.draft_id}",
      {:timer_expired, %{
        team_id: state.current_team_id,
        total_seconds: state.total_seconds
      }}
    )
  end
  
  defp persist_timer_state(state) do
    # Update the draft's timer-related fields
    Drafts.update_draft_timer_state(state.draft_id, %{
      timer_status: Atom.to_string(state.status),
      timer_remaining_seconds: state.remaining_seconds,
      timer_started_at: if(state.status in [:running, :paused], do: DateTime.utc_now(), else: nil),
      current_turn_team_id: state.current_team_id,
      current_pick_deadline: state.deadline
    })
  end
  
  defp clear_timer_state(draft_id) do
    Drafts.update_draft_timer_state(draft_id, %{
      timer_status: "stopped",
      timer_remaining_seconds: 0,
      timer_started_at: nil,
      current_turn_team_id: nil,
      current_pick_deadline: nil
    })
  end
  
  defp recover_timer_state(draft_id) do
    case Drafts.get_draft!(draft_id) do
      %{timer_status: status, timer_remaining_seconds: remaining, current_turn_team_id: team_id, current_pick_deadline: deadline}
      when status in ["running", "paused"] and not is_nil(deadline) ->
        
        # Calculate actual remaining time based on deadline
        now = DateTime.utc_now()
        actual_remaining = DateTime.diff(deadline, now, :second)
        
        # If deadline has passed, mark as expired
        {recovered_status, recovered_remaining} = 
          if actual_remaining <= 0 do
            {:expired, 0}
          else
            {String.to_existing_atom(status), actual_remaining}
          end
        
        state = %__MODULE__{
          draft_id: draft_id,
          status: recovered_status,
          remaining_seconds: recovered_remaining,
          total_seconds: remaining, # We don't persist total, so use remaining as approximation
          current_team_id: team_id,
          deadline: deadline,
          tick_ref: if(recovered_status == :running, do: schedule_tick(), else: nil)
        }
        
        {:ok, state}
      
      _ ->
        {:error, :no_timer_state}
    end
  end
end