defmodule AceAppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Database Metrics
      summary("ace_app.repo.query.total_time", unit: {:native, :millisecond}),
      summary("ace_app.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("ace_app.repo.query.query_time", unit: {:native, :millisecond}),
      summary("ace_app.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("ace_app.repo.query.idle_time", unit: {:native, :millisecond}),

      # Draft System Metrics
      counter("ace_app.drafts.created.count"),
      counter("ace_app.drafts.started.count"),
      counter("ace_app.drafts.completed.count"),
      counter("ace_app.picks.made.count"),
      counter("ace_app.teams.created.count"),
      counter("ace_app.players.created.count"),
      
      # Draft Performance Metrics
      summary("ace_app.draft.pick_duration", 
        unit: {:native, :millisecond},
        tags: [:draft_id, :team_id]
      ),
      summary("ace_app.draft.setup_duration",
        unit: {:native, :millisecond},
        tags: [:draft_id]
      ),
      
      # Real-time Connection Metrics
      last_value("ace_app.drafts.active.count"),
      last_value("ace_app.drafts.connections.count"),
      last_value("ace_app.drafts.participants.count"),
      
      # Queue System Metrics
      counter("ace_app.queue.picks_added.count"),
      counter("ace_app.queue.picks_executed.count"),
      counter("ace_app.queue.conflicts_resolved.count"),
      
      # Timer System Metrics
      counter("ace_app.timer.started.count"),
      counter("ace_app.timer.expired.count"),
      summary("ace_app.timer.duration", unit: {:native, :second}),
      
      # Chat System Metrics
      counter("ace_app.chat.messages.count"),
      counter("ace_app.chat.channels.created.count"),
      
      # File Upload Metrics
      counter("ace_app.uploads.started.count"),
      counter("ace_app.uploads.completed.count"),
      counter("ace_app.uploads.failed.count"),
      summary("ace_app.uploads.file_size", unit: {:byte, :kilobyte}),
      
      # Mock Draft Metrics
      counter("ace_app.mock_drafts.created.count"),
      counter("ace_app.mock_drafts.predictions.count"),
      counter("ace_app.mock_drafts.participants.count")
    ]
  end

  defp periodic_measurements do
    # Check if periodic measurements are enabled (disabled by default in dev)
    if Application.get_env(:ace_app, :telemetry, [])[:enable_periodic_measurements] do
      [
        # A module, function and arguments to be invoked periodically.
        # This function must call :telemetry.execute/3 and a metric must be added above.
        {AceAppWeb.Telemetry, :execute_periodic_measurements, []}
      ]
    else
      []
    end
  end

  def execute_periodic_measurements do
    # Draft System Measurements - handle case when DB is not ready
    # Note: This is disabled by default in development to reduce query noise
    # To enable: set `enable_periodic_measurements: true` in config/dev.exs
    try do
      active_drafts_count = count_active_drafts()
      total_connections_count = count_total_connections()
      total_participants_count = count_total_participants()

      :telemetry.execute([:ace_app, :drafts, :active], %{count: active_drafts_count})
      :telemetry.execute([:ace_app, :drafts, :connections], %{count: total_connections_count})
      :telemetry.execute([:ace_app, :drafts, :participants], %{count: total_participants_count})
    rescue
      # Ignore errors during startup when database might not be ready
      _ -> :ok
    end
  end

  defp count_active_drafts do
    # Count drafts in active, setup, or paused status
    case AceApp.Repo.query("SELECT COUNT(*) FROM drafts WHERE status IN ('setup', 'active', 'paused')", []) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp count_total_connections do
    # Count Phoenix channels/LiveView processes
    # This is an approximation - in production you'd want more sophisticated tracking
    Process.list() 
    |> Enum.filter(&(Process.info(&1, :dictionary)[:dictionary][:"$initial_call"] != nil))
    |> Enum.count()
  end

  defp count_total_participants do
    # Count total teams across all active drafts
    case AceApp.Repo.query("SELECT COUNT(*) FROM teams t JOIN drafts d ON t.draft_id = d.id WHERE d.status IN ('setup', 'active', 'paused')", []) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end
end
