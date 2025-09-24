defmodule AceApp.Drafts.TimerManager do
  @moduledoc """
  Manages the lifecycle of DraftTimer processes.
  
  Provides a clean API for starting, stopping, and managing timer processes
  for drafts without directly interacting with the DynamicSupervisor.
  """
  
  require Logger
  
  alias AceApp.Drafts.DraftTimer
  
  @doc """
  Starts a timer process for the given draft if one doesn't already exist.
  """
  def start_timer_for_draft(draft_id) do
    case DraftTimer.timer_exists?(draft_id) do
      true ->
        Logger.debug("Timer already exists for draft #{draft_id}")
        {:ok, :already_exists}
      
      false ->
        case DynamicSupervisor.start_child(
          AceApp.DraftTimerSupervisor,
          {DraftTimer, draft_id}
        ) do
          {:ok, pid} ->
            Logger.info("Started timer process for draft #{draft_id}, pid: #{inspect(pid)}")
            {:ok, pid}
          
          {:error, {:already_started, pid}} ->
            Logger.debug("Timer process already started for draft #{draft_id}, pid: #{inspect(pid)}")
            {:ok, pid}
          
          {:error, reason} ->
            Logger.error("Failed to start timer for draft #{draft_id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end
  
  @doc """
  Stops the timer process for the given draft.
  """
  def stop_timer_for_draft(draft_id) do
    case Registry.lookup(AceApp.DraftTimerRegistry, draft_id) do
      [{pid, _}] ->
        Logger.info("Stopping timer process for draft #{draft_id}")
        DynamicSupervisor.terminate_child(AceApp.DraftTimerSupervisor, pid)
      
      [] ->
        Logger.debug("No timer process found for draft #{draft_id}")
        {:ok, :not_found}
    end
  end
  
  @doc """
  Starts a timer with the given duration for testing purposes.
  """
  def start_timer(draft_id, duration_seconds) do
    start_pick_timer(draft_id, 1, duration_seconds)
  end

  @doc """
  Starts the countdown timer for a team's pick.
  Ensures a timer process exists before starting the countdown.
  """
  def start_pick_timer(draft_id, team_id, duration_seconds) do
    with {:ok, _} <- start_timer_for_draft(draft_id),
         :ok <- DraftTimer.start_timer(draft_id, team_id, duration_seconds) do
      {:ok, :timer_started}
    else
      error -> error
    end
  end
  
  @doc """
  Pauses the timer for the given draft.
  """
  def pause_timer(draft_id) do
    case DraftTimer.timer_exists?(draft_id) do
      true -> DraftTimer.pause_timer(draft_id)
      false -> {:error, :timer_not_found}
    end
  end
  
  @doc """
  Resumes the timer for the given draft.
  """
  def resume_timer(draft_id) do
    case DraftTimer.timer_exists?(draft_id) do
      true -> DraftTimer.resume_timer(draft_id)
      false -> {:error, :timer_not_found}
    end
  end
  
  @doc """
  Stops the timer countdown (but keeps the process alive).
  """
  def stop_timer(draft_id) do
    case DraftTimer.timer_exists?(draft_id) do
      true -> DraftTimer.stop_timer(draft_id)
      false -> {:error, :timer_not_found}
    end
  end
  
  @doc """
  Gets the current timer state for the given draft.
  """
  def get_timer_state(draft_id) do
    DraftTimer.get_state(draft_id)
  end
  
  @doc """
  Returns a list of all active timer processes.
  Useful for monitoring and debugging.
  """
  def list_active_timers do
    Registry.select(AceApp.DraftTimerRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end
  
  @doc """
  Checks if a timer process is running for the given draft.
  """
  def timer_running?(draft_id) do
    case get_timer_state(draft_id) do
      {:ok, %{status: :running}} -> true
      _ -> false
    end
  end
  
  @doc """
  Gracefully shuts down all timer processes.
  Used during application shutdown.
  """
  def shutdown_all_timers do
    list_active_timers()
    |> Enum.each(fn {draft_id, _pid} ->
      Logger.info("Shutting down timer for draft #{draft_id}")
      stop_timer_for_draft(draft_id)
    end)
  end
end