defmodule AceApp.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ace_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
    
    # Game data setup will run asynchronously after app starts
    IO.puts("✅ Migrations completed. Game data will be updated after app starts.")
  end
  
  def setup_game_data do
    load_app()
    
    try do
      case AceApp.GameDataSetup.setup_all_data() do
        :ok -> 
          IO.puts("✅ Game data setup completed successfully")
        {:error, reason} -> 
          IO.puts("⚠️ Game data setup failed, but continuing startup: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("⚠️ Game data setup crashed, but continuing startup: #{inspect(error)}")
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end