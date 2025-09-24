# Update champion image URLs to use Community Dragon SPLASH ART CDN
# This ensures we get the full splash art images, not just square icons
import Ecto.Query
alias AceApp.Repo
alias AceApp.LoL.Champion

# Champion name to Community Dragon splash art URL mapping
# Format: https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/[championId]/[championId]000.jpg
champion_splash_urls = %{
  "Aatrox" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/266/266000.jpg",
  "Ahri" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/103/103000.jpg",
  "Aphelios" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/523/523000.jpg",
  "Azir" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/268/268000.jpg",
  "Caitlyn" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/51/51000.jpg",
  "Camille" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/164/164000.jpg",
  "Darius" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/122/122000.jpg",
  "Elise" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/60/60000.jpg",
  "Ezreal" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/81/81000.jpg",
  "Fiora" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/114/114000.jpg",
  "Garen" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/86/86000.jpg",
  "Graves" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/104/104000.jpg",
  "Janna" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/40/40000.jpg",
  "Jinx" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/222/222000.jpg",
  "Kai'Sa" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/145/145000.jpg",
  "Katarina" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/55/55000.jpg",
  "Kha'Zix" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/121/121000.jpg",
  "Kindred" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/203/203000.jpg",
  "LeBlanc" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/7/7000.jpg",
  "Lee Sin" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/64/64000.jpg",
  "Leona" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/89/89000.jpg",
  "Lulu" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/117/117000.jpg",
  "Lux" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/99/99000.jpg",
  "Morgana" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/25/25000.jpg",
  "Orianna" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/61/61000.jpg",
  "Ornn" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/516/516000.jpg",
  "Pyke" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/555/555000.jpg",
  "Sejuani" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/113/113000.jpg",
  "Syndra" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/134/134000.jpg",
  "Thresh" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/412/412000.jpg",
  "Vayne" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/67/67000.jpg",
  "Yasuo" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/157/157000.jpg",
  "Zed" => "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/champion-splashes/238/238000.jpg"
}

# Update each champion's image URL to use splash art
updated_count = 0
Enum.each(champion_splash_urls, fn {champion_name, new_splash_url} ->
  case Repo.get_by(Champion, name: champion_name) do
    nil -> 
      IO.puts("Champion '#{champion_name}' not found")
    champion ->
      changeset = Champion.changeset(champion, %{image_url: new_splash_url})
      case Repo.update(changeset) do
        {:ok, _} -> 
          IO.puts("✅ Updated #{champion_name} with splash art URL")
          updated_count = updated_count + 1
        {:error, changeset} -> 
          IO.puts("❌ Failed to update #{champion_name}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("\n🎨 Champion splash art URL update complete!")
IO.puts("📊 Updated #{updated_count} champions with Community Dragon splash art URLs")
IO.puts("🔗 All champions now use: https://raw.communitydragon.org/.../champion-splashes/...")