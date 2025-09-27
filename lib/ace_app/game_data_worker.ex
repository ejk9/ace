defmodule AceApp.GameDataWorker do
  @moduledoc """
  GenServer that handles game data updates asynchronously after app startup.
  This prevents blocking the deployment while still keeping data fresh.
  """
  
  use GenServer
  require Logger
  
  @startup_delay 5_000  # Wait 5 seconds after app starts
  @update_interval 24 * 60 * 60 * 1000  # Check for updates every 24 hours
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @impl true
  def init(_) do
    # Schedule initial game data setup after a short delay
    Process.send_after(self(), :initial_setup, @startup_delay)
    {:ok, %{}}
  end
  
  @impl true
  def handle_info(:initial_setup, state) do
    Logger.info("🎮 Starting async game data setup...")
    
    Task.start(fn ->
      try do
        AceApp.GameDataSetup.setup_all_data_parallel()
      rescue
        error ->
          Logger.error("❌ Async game data setup failed: #{inspect(error)}")
      end
    end)
    
    # Schedule periodic updates
    Process.send_after(self(), :periodic_update, @update_interval)
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:periodic_update, state) do
    Logger.info("🔄 Running periodic game data update...")
    
    Task.start(fn ->
      try do
        AceApp.GameDataSetup.setup_all_data_parallel(force_update: true)
      rescue
        error ->
          Logger.error("❌ Periodic game data update failed: #{inspect(error)}")
      end
    end)
    
    # Schedule next update
    Process.send_after(self(), :periodic_update, @update_interval)
    {:noreply, state}
  end
end