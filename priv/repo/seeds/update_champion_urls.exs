# Update champion image URLs to use CommunityDragon
import Ecto.Query
alias AceApp.Repo

# Champion ID to CommunityDragon URL mapping
champion_urls = %{
  "Jinx" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/222/222000.jpg",
  "Garen" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/86/86000.jpg",
  "Yasuo" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/157/157000.jpg",
  "Ahri" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/103/103000.jpg",
  "Lee Sin" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/64/64000.jpg",
  "Thresh" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/412/412000.jpg",
  "Ezreal" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/81/81000.jpg",
  "Lux" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/99/99000.jpg",
  "Zed" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/238/238000.jpg",
  "Graves" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/104/104000.jpg",
  "Darius" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/122/122000.jpg",
  "Janna" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/40/40000.jpg",
  "Vayne" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/67/67000.jpg",
  "Katarina" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/55/55000.jpg",
  "Elise" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/60/60000.jpg",
  "Fiora" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/114/114000.jpg",
  "Morgana" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/25/25000.jpg",
  "Caitlyn" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/51/51000.jpg",
  "Azir" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/268/268000.jpg",
  "Kha'Zix" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/121/121000.jpg",
  "Ornn" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/516/516000.jpg",
  "Leona" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/89/89000.jpg",
  "Kai'Sa" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/145/145000.jpg",
  "Orianna" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/61/61000.jpg",
  "Kindred" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/203/203000.jpg"
}

# Update each champion's image URL
Enum.each(champion_urls, fn {champion_name, new_url} ->
  case Repo.get_by(AceApp.LoL.Champion, name: champion_name) do
    nil -> 
      IO.puts("Champion '#{champion_name}' not found")
    champion ->
      champion
      |> AceApp.LoL.Champion.changeset(%{image_url: new_url})
      |> Repo.update()
      |> case do
        {:ok, _} -> IO.puts("Updated #{champion_name} with CommunityDragon URL")
        {:error, changeset} -> IO.puts("Failed to update #{champion_name}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("Champion URL update complete!")