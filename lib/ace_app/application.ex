defmodule AceApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AceAppWeb.Telemetry,
      AceApp.Repo,
      {DNSCluster, query: Application.get_env(:ace_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AceApp.PubSub},
      # Registry for DraftTimer processes
      {Registry, keys: :unique, name: AceApp.DraftTimerRegistry},
      # Supervisor for DraftTimer processes
      {DynamicSupervisor, strategy: :one_for_one, name: AceApp.DraftTimerSupervisor},
      # Discord notification queue for sequential message delivery
      AceApp.DiscordQueue,
      # Start to serve requests, typically the last entry
      AceAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AceApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AceAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
