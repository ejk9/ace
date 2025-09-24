defmodule Mix.Tasks.SetupGameData do
  @moduledoc """
  Comprehensive deployment task for setting up all League of Legends game data.
  
  This task orchestrates the complete setup of champion and skin data for deployment.
  It handles database migrations, champion population, and skin data setup.
  
  Usage:
    mix setup_game_data                    # Full setup with latest patch
    mix setup_game_data --patch=14.21.1   # Setup with specific patch
    mix setup_game_data --champions-only  # Only populate champions
    mix setup_game_data --skins-only      # Only populate skins (requires champions)
    mix setup_game_data --force-update    # Force update existing data
  """
  
  use Mix.Task
  require Logger

  @shortdoc "Setup all League of Legends game data for deployment"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [
        patch: :string, 
        champions_only: :boolean, 
        skins_only: :boolean, 
        force_update: :boolean,
        skip_migration: :boolean
      ],
      aliases: [p: :patch, c: :champions_only, s: :skins_only, f: :force_update]
    )
    
    Logger.info("🚀 Starting League of Legends game data setup for deployment")
    
    start_time = System.monotonic_time()
    
    try do
      # Step 1: Run migrations unless skipped
      unless opts[:skip_migration] do
        run_migrations()
      end
      
      # Step 2: Setup champions unless skins-only
      unless opts[:skins_only] do
        setup_champions(opts)
      end
      
      # Step 3: Setup skins unless champions-only
      unless opts[:champions_only] do
        setup_skins(opts)
      end
      
      # Step 4: Verify setup
      verify_setup()
      
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :second)
      
      Logger.info("✅ Game data setup completed successfully in #{duration} seconds!")
      Logger.info("🎮 Your deployment is ready with League of Legends champion and skin data")
      
    rescue
      error ->
        Logger.error("❌ Game data setup failed: #{inspect(error)}")
        Logger.error("🔧 Try running with --force-update or check your network connection")
        System.halt(1)
    end
  end
  
  defp run_migrations do
    Logger.info("📊 Running database migrations...")
    
    case Mix.Task.run("ecto.migrate") do
      :ok -> Logger.info("✅ Database migrations completed")
      _ -> Logger.info("⚠️  Migration warnings (this is usually fine)")
    end
  end
  
  defp setup_champions(opts) do
    Logger.info("🏆 Setting up champion data...")
    
    champion_args = build_champion_args(opts)
    
    case Mix.Task.run("populate_champions", champion_args) do
      :ok -> Logger.info("✅ Champion data setup completed")
      _ -> raise "Champion population failed"
    end
  end
  
  defp setup_skins(opts) do
    Logger.info("🎨 Setting up champion skin data...")
    
    skin_args = build_skin_args(opts)
    
    case Mix.Task.run("populate_skins", skin_args) do
      :ok -> Logger.info("✅ Skin data setup completed")
      _ -> raise "Skin population failed"
    end
  end
  
  defp verify_setup do
    Logger.info("🔍 Verifying game data setup...")
    
    champion_stats = AceApp.LoL.get_champion_stats()
    skin_stats = AceApp.LoL.get_skin_stats()
    
    Logger.info("📈 Setup Statistics:")
    Logger.info("  Champions: #{champion_stats.enabled}/#{champion_stats.total} enabled")
    Logger.info("  Skins: #{skin_stats.enabled_skins} total across #{skin_stats.champions_with_skins} champions")
    Logger.info("  Average: #{Float.round(skin_stats.average_skins_per_champion, 1)} skins per champion")
    
    # Verify critical data exists
    if champion_stats.enabled == 0 do
      raise "No champions found! Champion population may have failed."
    end
    
    if skin_stats.enabled_skins == 0 do
      Logger.warning("⚠️  No skins found - skin population may have failed or been skipped")
    end
    
    Logger.info("✅ Game data verification completed")
  end
  
  defp build_champion_args(opts) do
    args = []
    
    args = if opts[:patch], do: ["--patch=#{opts[:patch]}" | args], else: args
    args = if opts[:force_update], do: ["--force-update" | args], else: args
    
    args
  end
  
  defp build_skin_args(opts) do
    args = []
    
    args = if opts[:force_update], do: ["--force-update" | args], else: args
    
    args
  end
end