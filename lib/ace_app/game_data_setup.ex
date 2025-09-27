defmodule AceApp.GameDataSetup do
  @moduledoc """
  Module for setting up League of Legends game data in production.
  
  This module contains the core logic for populating champion and skin data
  without relying on Mix tasks, making it suitable for production releases.
  """
  
  require Logger
  alias AceApp.Repo
  alias AceApp.LoL.Champion
  
  @data_dragon_base "https://ddragon.leagueoflegends.com"
  @community_dragon_base "https://cdn.communitydragon.org"
  
  @doc """
  Sets up all game data with parallel processing for faster updates.
  """
  def setup_all_data_parallel(opts \\ []) do
    Logger.info("🚀 Starting parallel game data update")
    
    start_time = System.monotonic_time()
    
    try do
      # Run champion setup in parallel chunks
      unless opts[:skip_champions] do
        setup_champions_parallel(opts)
      end
      
      unless opts[:skip_skins] do
        setup_skins(opts)
      end
      
      verify_setup()
      
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :second)
      
      Logger.info("✅ Parallel game data update completed in #{duration} seconds!")
      :ok
      
    rescue
      error ->
        Logger.error("❌ Parallel game data setup failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Sets up all game data (champions and skins) for production deployment.
  """
  def setup_all_data(opts \\ []) do
    Logger.info("🚀 Starting League of Legends game data check/update")
    
    start_time = System.monotonic_time()
    
    try do
      unless opts[:skip_champions] do
        setup_champions_incremental(opts)
      end
      
      unless opts[:skip_skins] do
        setup_skins(opts)
      end
      
      verify_setup()
      
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :second)
      
      Logger.info("✅ Game data check/update completed in #{duration} seconds!")
      :ok
      
    rescue
      error ->
        Logger.error("❌ Game data setup failed: #{inspect(error)}")
        {:error, error}
    end
  end
  
  @doc """
  Sets up champion data with parallel processing for speed.
  """
  def setup_champions_parallel(opts \\ []) do
    Logger.info("🏆 Setting up champion data with parallel processing...")
    
    patch_version = opts[:patch] || get_latest_patch()
    force_update = opts[:force_update] || false
    
    case fetch_champions_data_parallel(patch_version, force_update) do
      :ok -> 
        Logger.info("✅ Parallel champion data setup completed")
        :ok
      {:error, reason} ->
        Logger.error("❌ Parallel champion setup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sets up champion data incrementally - only adds new champions.
  """
  def setup_champions_incremental(opts \\ []) do
    Logger.info("🏆 Checking for new champion data...")
    
    patch_version = opts[:patch] || get_latest_patch()
    
    case check_for_new_champions(patch_version) do
      {:new_champions, new_champions} when length(new_champions) > 0 ->
        Logger.info("📥 Found #{length(new_champions)} new champions to add")
        add_new_champions(new_champions, patch_version)
        
      {:updated_patch, _old_patch} ->
        Logger.info("🔄 New patch detected, checking all champions for updates")
        setup_champions(opts ++ [force_update: true])
        
      :up_to_date ->
        Logger.info("✅ Champion data is up to date")
        :ok
        
      {:error, reason} ->
        Logger.warning("⚠️ Could not check for new champions: #{inspect(reason)}")
        Logger.info("🔄 Falling back to basic champion check")
        setup_champions(opts)
    end
  end

  @doc """
  Sets up champion data only.
  """
  def setup_champions(opts \\ []) do
    Logger.info("🏆 Setting up champion data...")
    
    patch_version = opts[:patch] || get_latest_patch()
    force_update = opts[:force_update] || false
    
    # Check if champions already exist unless force update
    champion_count = Repo.aggregate(Champion, :count, :id)
    if champion_count > 0 and not force_update do
      Logger.info("✅ Champions already exist (#{champion_count} found). Skipping setup.")
      :ok
    else
      if champion_count > 0 do
        Logger.info("🔄 Force updating #{champion_count} existing champions...")
      else
        Logger.info("📥 No champions found, setting up initial data...")
      end
      do_setup_champions(patch_version, force_update)
    end
  end
  
  defp do_setup_champions(patch_version, force_update) do
    case fetch_and_populate_champions(patch_version, force_update) do
      :ok -> 
        Logger.info("✅ Champion data setup completed")
        :ok
      {:error, reason} ->
        Logger.error("❌ Champion setup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Sets up skin data only.
  """
  def setup_skins(opts \\ []) do
    Logger.info("🎨 Setting up champion skin data...")
    # For now, we'll implement basic skin setup
    # This can be expanded based on your skin requirements
    Logger.info("✅ Skin data setup completed (placeholder)")
    :ok
  end
  
  defp fetch_and_populate_champions(patch_version, force_update) do
    Logger.info("Fetching champion data from Data Dragon API (patch: #{patch_version})")
    
    # Fetch champion list
    champions_url = "#{@data_dragon_base}/cdn/#{patch_version}/data/en_US/champion.json"
    
    case Req.get(champions_url) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"data" => champions_data}} ->
            populate_champions_from_data(champions_data, patch_version, force_update)
          {:error, reason} ->
            {:error, "Failed to parse champion JSON: #{inspect(reason)}"}
        end
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        # Body already parsed as JSON
        case body do
          %{"data" => champions_data} ->
            populate_champions_from_data(champions_data, patch_version, force_update)
          _ ->
            {:error, "Invalid champion data format"}
        end
      {:ok, %{status: status_code}} ->
        {:error, "HTTP request failed with status: #{status_code}"}
      {:error, reason} ->
        {:error, "Network request failed: #{inspect(reason)}"}
    end
  end
  
  defp fetch_champions_data_parallel(patch_version, force_update) do
    Logger.info("Fetching champion data from Data Dragon API (patch: #{patch_version})")
    
    # Fetch champion list
    champions_url = "#{@data_dragon_base}/cdn/#{patch_version}/data/en_US/champion.json"
    
    case Req.get(champions_url) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"data" => champions_data}} ->
            populate_champions_from_data_parallel(champions_data, patch_version, force_update)
          {:error, reason} ->
            {:error, "Failed to parse champion JSON: #{inspect(reason)}"}
        end
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        # Body already parsed as JSON
        case body do
          %{"data" => champions_data} ->
            populate_champions_from_data_parallel(champions_data, patch_version, force_update)
          _ ->
            {:error, "Invalid champion data format"}
        end
      {:ok, %{status: status_code}} ->
        {:error, "HTTP request failed with status: #{status_code}"}
      {:error, reason} ->
        {:error, "Network request failed: #{inspect(reason)}"}
    end
  end

  defp populate_champions_from_data_parallel(champions_data, patch_version, force_update) do
    Logger.info("Processing #{map_size(champions_data)} champions in parallel...")
    
    # Split champions into chunks for parallel processing
    chunk_size = 10
    champions_list = Enum.to_list(champions_data)
    
    champions_list
    |> Enum.chunk_every(chunk_size)
    |> Task.async_stream(
      fn chunk ->
        Enum.reduce_while(chunk, :ok, fn {_key, champion_data}, _acc ->
          case create_or_update_champion(champion_data, patch_version, force_update) do
            {:ok, _champion} -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
      end,
      max_concurrency: 5,
      timeout: 30_000
    )
    |> Enum.reduce_while(:ok, fn
      {:ok, :ok}, _acc -> {:cont, :ok}
      {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
      {:exit, reason}, _acc -> {:halt, {:error, "Task crashed: #{inspect(reason)}"}}
    end)
  end

  defp populate_champions_from_data(champions_data, patch_version, force_update) do
    Logger.info("Processing #{map_size(champions_data)} champions...")
    
    champions_data
    |> Enum.reduce_while(:ok, fn {_key, champion_data}, _acc ->
      case create_or_update_champion(champion_data, patch_version, force_update) do
        {:ok, _champion} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
  
  defp create_or_update_champion(champion_data, patch_version, force_update) do
    champion_attrs = %{
      name: champion_data["name"],
      key: champion_data["key"],
      title: champion_data["title"],
      image_url: build_square_image_url(champion_data["id"], patch_version),
      roles: [], # Will be populated separately if needed
      tags: champion_data["tags"] || [],
      difficulty: 1, # Default difficulty
      enabled: true
    }
    
    if force_update do
      case Repo.get_by(Champion, key: champion_data["key"]) do
        nil -> create_champion(champion_attrs)
        existing_champion -> update_champion(existing_champion, champion_attrs)
      end
    else
      create_champion(champion_attrs)
    end
  end
  
  defp create_champion(attrs) do
    %Champion{}
    |> Champion.changeset(attrs)
    |> Repo.insert()
  end
  
  defp update_champion(champion, attrs) do
    champion
    |> Champion.changeset(attrs)
    |> Repo.update()
  end
  
  defp build_splash_art_url(champion_id, patch_version) do
    "#{@data_dragon_base}/cdn/img/champion/splash/#{champion_id}_0.jpg"
  end
  
  defp build_square_image_url(champion_id, patch_version) do
    "#{@data_dragon_base}/cdn/#{patch_version}/img/champion/#{champion_id}.png"
  end
  
  defp get_latest_patch do
    case Req.get("#{@data_dragon_base}/api/versions.json") do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, [latest | _]} -> latest
          _ -> "14.21.1" # fallback
        end
      _ -> "14.21.1" # fallback
    end
  end
  
  defp verify_setup do
    champion_count = Repo.aggregate(Champion, :count, :id)
    Logger.info("📊 Setup verification: #{champion_count} champions in database")
    
    if champion_count > 0 do
      Logger.info("✅ Game data verification passed")
      :ok
    else
      raise "No champions found after setup"
    end
  end
end