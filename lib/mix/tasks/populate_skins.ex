defmodule Mix.Tasks.PopulateSkins do
  @moduledoc """
  Mix task to populate champion skins from Community Dragon API.
  
  This task fetches skin data for all champions and populates the champion_skins table.
  Includes support for splash art, loading screens, and skin metadata.
  
  Usage:
    mix populate_skins
    mix populate_skins --champion-id=103  # Populate skins for specific champion
    mix populate_skins --force-update     # Update existing skin data
  """
  
  use Mix.Task
  require Logger
  alias AceApp.{Repo, LoL}
  alias AceApp.LoL.ChampionSkin

  @shortdoc "Populate champion skins from Community Dragon API"
  
  @community_dragon_base "https://cdn.communitydragon.org"
  @raw_community_dragon "https://raw.communitydragon.org"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [force_update: :boolean, champion_id: :integer],
      aliases: [f: :force_update, c: :champion_id]
    )
    
    force_update = opts[:force_update] || false
    champion_id = opts[:champion_id]
    
    Logger.info("🎨 Starting champion skin population")
    Logger.info("📥 Force update mode: #{force_update}")
    
    champions = get_champions(champion_id)
    
    Logger.info("🎯 Processing #{length(champions)} champion(s)")
    
    results = %{created: 0, updated: 0, skipped: 0, errors: 0}
    
    final_results = 
      champions
      |> Enum.reduce(results, fn champion, acc ->
        case populate_champion_skins(champion, force_update) do
          {:ok, skin_results} ->
            %{
              created: acc.created + skin_results.created,
              updated: acc.updated + skin_results.updated,
              skipped: acc.skipped + skin_results.skipped,
              errors: acc.errors
            }
          {:error, reason} ->
            Logger.error("❌ Failed to populate skins for #{champion.name}: #{reason}")
            Map.update!(acc, :errors, &(&1 + 1))
        end
      end)
    
    Logger.info("✅ Skin population completed!")
    Logger.info("📊 Created: #{final_results.created} | Updated: #{final_results.updated} | Skipped: #{final_results.skipped} | Errors: #{final_results.errors}")
  end
  
  defp get_champions(nil) do
    LoL.list_enabled_champions()
  end
  
  defp get_champions(champion_id) do
    try do
      champion = LoL.get_champion!(champion_id)
      [champion]
    rescue
      Ecto.NoResultsError ->
        Logger.error("❌ Champion with ID #{champion_id} not found")
        []
    end
  end
  
  defp populate_champion_skins(champion, force_update) do
    Logger.info("🎨 Processing skins for #{champion.name} (ID: #{champion.key})")
    
    with {:ok, skin_data} <- fetch_champion_skin_data(champion.key),
         {:ok, results} <- process_skins(champion, skin_data, force_update) do
      
      Logger.info("✅ #{champion.name}: Created #{results.created}, Updated #{results.updated}, Skipped #{results.skipped}")
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp fetch_champion_skin_data(champion_key) do
    # Community Dragon provides champion skin data via their API
    url = "#{@raw_community_dragon}/latest/plugins/rcp-be-lol-game-data/global/default/v1/champions/#{champion_key}.json"
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"skins" => skins}}} ->
        {:ok, skins}
      {:ok, %{status: 200, body: _data}} ->
        Logger.warning("⚠️  No skins data found for champion #{champion_key}")
        {:ok, []}
      {:ok, %{status: 404}} ->
        Logger.warning("⚠️  Skin data not found for champion #{champion_key}")
        {:ok, []}
      {:ok, %{status: status}} ->
        Logger.error("❌ HTTP error #{status} fetching skin data for champion #{champion_key}")
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        Logger.error("❌ Network error fetching skin data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp process_skins(champion, skin_data, force_update) do
    results = %{created: 0, updated: 0, skipped: 0}
    
    # Create default skin (skin_id: 0) if not in data
    all_skins = ensure_default_skin(champion, skin_data)
    
    final_results = 
      all_skins
      |> Enum.reduce(results, fn skin_data, acc ->
        case process_single_skin(champion, skin_data, force_update) do
          {:created, _} -> Map.update!(acc, :created, &(&1 + 1))
          {:updated, _} -> Map.update!(acc, :updated, &(&1 + 1))
          {:skipped, _} -> Map.update!(acc, :skipped, &(&1 + 1))
          {:error, reason} ->
            Logger.warning("⚠️  Failed to process skin #{skin_data["name"] || "Unknown"}: #{reason}")
            acc
        end
      end)
    
    {:ok, final_results}
  end
  
  defp ensure_default_skin(champion, skin_data) do
    has_default = Enum.any?(skin_data, fn skin -> skin["id"] == 0 end)
    
    if has_default do
      skin_data
    else
      default_skin = %{
        "id" => 0,
        "name" => champion.name,
        "splashPath" => "/lol-game-data/assets/ASSETS/Characters/#{champion.name}/Skins/Base/#{champion.name}_Splash_0.jpg",
        "loadScreenPath" => "/lol-game-data/assets/ASSETS/Characters/#{champion.name}/Skins/Base/#{champion.name}_LoadScreen_0.jpg"
      }
      [default_skin | skin_data]
    end
  end
  
  defp process_single_skin(champion, skin_data, force_update) do
    skin_id = skin_data["id"] || 0
    existing = Repo.get_by(ChampionSkin, champion_id: champion.id, skin_id: skin_id)
    
    champion_id_int = String.to_integer(champion.key)
    
    skin_attrs = %{
      champion_id: champion.id,
      skin_id: skin_id,
      name: skin_data["name"] || champion.name,
      splash_url: build_splash_url(champion_id_int, skin_id),
      loading_url: build_loading_url(champion_id_int, skin_id),
      tile_url: build_tile_url(champion_id_int, skin_id),
      rarity: determine_rarity(skin_data),
      cost: skin_data["cost"] || 0,
      enabled: true,
      chromas: extract_chromas(skin_data)
    }
    
    cond do
      is_nil(existing) ->
        case create_skin(skin_attrs) do
          {:ok, skin} -> 
            Logger.debug("➕ Created skin: #{skin.name}")
            {:created, skin}
          {:error, changeset} -> 
            {:error, "Validation failed: #{inspect(changeset.errors)}"}
        end
      
      force_update ->
        case update_skin(existing, skin_attrs) do
          {:ok, skin} ->
            Logger.debug("🔄 Updated skin: #{skin.name}")
            {:updated, skin}
          {:error, changeset} ->
            {:error, "Update failed: #{inspect(changeset.errors)}"}
        end
      
      true ->
        {:skipped, existing}
    end
  end
  
  defp create_skin(attrs) do
    %ChampionSkin{}
    |> ChampionSkin.changeset(attrs)
    |> Repo.insert()
  end
  
  defp update_skin(skin, attrs) do
    skin
    |> ChampionSkin.changeset(attrs)
    |> Repo.update()
  end
  
  defp build_splash_url(champion_id, skin_id) do
    "#{@community_dragon_base}/latest/champion/#{champion_id}/splash-art/centered/skin/#{skin_id}"
  end
  
  defp build_loading_url(champion_id, skin_id) do
    "#{@community_dragon_base}/latest/champion/#{champion_id}/splash-art/skin/#{skin_id}"
  end
  
  defp build_tile_url(champion_id, skin_id) do
    "#{@community_dragon_base}/latest/champion/#{champion_id}/tile/skin/#{skin_id}"
  end
  
  defp determine_rarity(skin_data) do
    raw_rarity = case skin_data["rarity"] do
      nil -> "common"
      rarity when is_map(rarity) -> Map.get(rarity, "rarity", "common")
      rarity when is_binary(rarity) -> String.downcase(rarity)
      _ -> "common"
    end
    
    # Map API rarity values to our schema enum
    case raw_rarity do
      r when r in ["common", "standard", "base", "normal"] -> "common"
      r when r in ["epic", "rare"] -> "epic" 
      r when r in ["legendary", "1350"] -> "legendary"
      r when r in ["mythic", "prestige"] -> "mythic"
      r when r in ["ultimate", "3250"] -> "ultimate"
      _ -> "common"
    end
  end
  
  defp extract_chromas(skin_data) do
    case skin_data["chromas"] do
      chromas when is_list(chromas) -> chromas
      _ -> []
    end
  end
end