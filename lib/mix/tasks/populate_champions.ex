defmodule Mix.Tasks.PopulateChampions do
  @moduledoc """
  Mix task to populate and update champion data from Data Dragon and Community Dragon APIs.
  
  This task fetches the latest champion data from Riot's Data Dragon API and 
  Community Dragon CDN to populate or update the champions table.
  
  Usage:
    mix populate_champions
    mix populate_champions --force-update  # Updates existing champions
    mix populate_champions --patch=14.1.1   # Uses specific patch version
  """
  
  use Mix.Task
  require Logger
  alias AceApp.Repo
  alias AceApp.LoL.Champion
  
  @shortdoc "Populate champions database from Data Dragon API"
  
  @data_dragon_base "https://ddragon.leagueoflegends.com"
  @community_dragon_base "https://cdn.communitydragon.org"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [force_update: :boolean, patch: :string],
      aliases: [f: :force_update, p: :patch]
    )
    
    patch_version = opts[:patch] || get_latest_patch_version()
    force_update = opts[:force_update] || false
    
    Logger.info("🎮 Starting champion data population for patch #{patch_version}")
    Logger.info("📥 Force update mode: #{force_update}")
    
    with {:ok, champion_data} <- fetch_champion_data(patch_version),
         {:ok, results} <- populate_champions(champion_data, force_update) do
      
      Logger.info("✅ Champion population completed successfully!")
      Logger.info("📊 Created: #{results.created} | Updated: #{results.updated} | Skipped: #{results.skipped}")
      
    else
      {:error, reason} -> 
        Logger.error("❌ Champion population failed: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp get_latest_patch_version do
    case Req.get("#{@data_dragon_base}/api/versions.json") do
      {:ok, %{status: 200, body: [latest | _]}} -> 
        Logger.info("🔄 Using latest patch version: #{latest}")
        latest
      error ->
        Logger.warning("⚠️  Failed to fetch latest patch, using fallback: #{inspect(error)}")
        "15.18.1"  # updated fallback version
    end
  end
  
  defp fetch_champion_data(patch_version) do
    Logger.info("📡 Fetching champion data from Data Dragon...")
    
    url = "#{@data_dragon_base}/cdn/#{patch_version}/data/en_US/champion.json"
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"data" => champions}}} ->
        Logger.info("🎯 Successfully fetched #{map_size(champions)} champions")
        {:ok, champions}
      {:ok, %{status: status}} ->
        Logger.error("❌ HTTP error #{status} fetching champion data")
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        Logger.error("❌ Network error fetching champion data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp populate_champions(champion_data, force_update) do
    results = %{created: 0, updated: 0, skipped: 0}
    
    champion_data
    |> Enum.reduce(results, fn {_key, champ_data}, acc ->
      case process_champion(champ_data, force_update) do
        {:created, _} -> Map.update!(acc, :created, &(&1 + 1))
        {:updated, _} -> Map.update!(acc, :updated, &(&1 + 1))
        {:skipped, _} -> Map.update!(acc, :skipped, &(&1 + 1))
        {:error, reason} -> 
          Logger.warning("⚠️  Failed to process champion #{champ_data["name"]}: #{reason}")
          acc
      end
    end)
    |> then(&{:ok, &1})
  end
  
  defp process_champion(champ_data, force_update) do
    champion_id = String.to_integer(champ_data["key"])
    existing = Repo.get_by(Champion, key: champ_data["key"])
    
    champion_attrs = %{
      name: champ_data["name"],
      key: champ_data["key"],
      title: champ_data["title"],
      image_url: build_splash_url(champion_id),
      roles: normalize_roles(champ_data["tags"]),
      tags: champ_data["tags"] || [],
      difficulty: champ_data["info"]["difficulty"] || 1,
      enabled: true,
      release_date: Date.utc_today()  # Could be enhanced with actual release dates
    }
    
    cond do
      is_nil(existing) ->
        case create_champion(champion_attrs) do
          {:ok, champion} -> 
            Logger.info("➕ Created champion: #{champion.name}")
            {:created, champion}
          {:error, changeset} -> 
            {:error, "Validation failed: #{inspect(changeset.errors)}"}
        end
      
      force_update ->
        case update_champion(existing, champion_attrs) do
          {:ok, champion} ->
            Logger.info("🔄 Updated champion: #{champion.name}")
            {:updated, champion}
          {:error, changeset} ->
            {:error, "Update failed: #{inspect(changeset.errors)}"}
        end
      
      true ->
        Logger.debug("⏭️  Skipped existing champion: #{existing.name}")
        {:skipped, existing}
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
  
  defp build_splash_url(champion_id) do
    "#{@community_dragon_base}/latest/champion/#{champion_id}/splash-art/centered"
  end
  
  defp normalize_roles(tags) do
    # Map Data Dragon tags to standardized roles
    role_mapping = %{
      "Assassin" => "mid",
      "Fighter" => "top", 
      "Mage" => "mid",
      "Marksman" => "adc",
      "Support" => "support",
      "Tank" => "top"
    }
    
    tags
    |> Enum.map(&Map.get(role_mapping, &1, "flex"))
    |> Enum.uniq()
  end
end