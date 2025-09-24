# Fix champion image URLs to use proper Community Dragon CDN format
# Format: https://cdn.communitydragon.org/latest/champion/:championId/splash-art/centered
import Ecto.Query
alias AceApp.Repo
alias AceApp.LoL.Champion

# Champion name to proper Community Dragon CDN URL mapping
# Using the centered splash art format as requested
champion_cdn_urls = %{
  "Aatrox" => "https://cdn.communitydragon.org/latest/champion/266/splash-art/centered",
  "Ahri" => "https://cdn.communitydragon.org/latest/champion/103/splash-art/centered",
  "Aphelios" => "https://cdn.communitydragon.org/latest/champion/523/splash-art/centered",
  "Azir" => "https://cdn.communitydragon.org/latest/champion/268/splash-art/centered",
  "Caitlyn" => "https://cdn.communitydragon.org/latest/champion/51/splash-art/centered",
  "Camille" => "https://cdn.communitydragon.org/latest/champion/164/splash-art/centered",
  "Darius" => "https://cdn.communitydragon.org/latest/champion/122/splash-art/centered",
  "Elise" => "https://cdn.communitydragon.org/latest/champion/60/splash-art/centered",
  "Ezreal" => "https://cdn.communitydragon.org/latest/champion/81/splash-art/centered",
  "Fiora" => "https://cdn.communitydragon.org/latest/champion/114/splash-art/centered",
  "Garen" => "https://cdn.communitydragon.org/latest/champion/86/splash-art/centered",
  "Graves" => "https://cdn.communitydragon.org/latest/champion/104/splash-art/centered",
  "Janna" => "https://cdn.communitydragon.org/latest/champion/40/splash-art/centered",
  "Jinx" => "https://cdn.communitydragon.org/latest/champion/222/splash-art/centered",
  "Kai'Sa" => "https://cdn.communitydragon.org/latest/champion/145/splash-art/centered",
  "Katarina" => "https://cdn.communitydragon.org/latest/champion/55/splash-art/centered",
  "Kha'Zix" => "https://cdn.communitydragon.org/latest/champion/121/splash-art/centered",
  "Kindred" => "https://cdn.communitydragon.org/latest/champion/203/splash-art/centered",
  "LeBlanc" => "https://cdn.communitydragon.org/latest/champion/7/splash-art/centered",
  "Lee Sin" => "https://cdn.communitydragon.org/latest/champion/64/splash-art/centered",
  "Leona" => "https://cdn.communitydragon.org/latest/champion/89/splash-art/centered",
  "Lulu" => "https://cdn.communitydragon.org/latest/champion/117/splash-art/centered",
  "Lux" => "https://cdn.communitydragon.org/latest/champion/99/splash-art/centered",
  "Morgana" => "https://cdn.communitydragon.org/latest/champion/25/splash-art/centered",
  "Orianna" => "https://cdn.communitydragon.org/latest/champion/61/splash-art/centered",
  "Ornn" => "https://cdn.communitydragon.org/latest/champion/516/splash-art/centered",
  "Pyke" => "https://cdn.communitydragon.org/latest/champion/555/splash-art/centered",
  "Sejuani" => "https://cdn.communitydragon.org/latest/champion/113/splash-art/centered",
  "Syndra" => "https://cdn.communitydragon.org/latest/champion/134/splash-art/centered",
  "Thresh" => "https://cdn.communitydragon.org/latest/champion/412/splash-art/centered",
  "Vayne" => "https://cdn.communitydragon.org/latest/champion/67/splash-art/centered",
  "Yasuo" => "https://cdn.communitydragon.org/latest/champion/157/splash-art/centered",
  "Zed" => "https://cdn.communitydragon.org/latest/champion/238/splash-art/centered"
}

IO.puts("🔧 Fixing champion URLs to use proper Community Dragon CDN format...")
IO.puts("📋 Format: https://cdn.communitydragon.org/latest/champion/:championId/splash-art/centered")
IO.puts("")

# Update each champion's image URL to use proper CDN format
updated_count = 0
failed_count = 0

Enum.each(champion_cdn_urls, fn {champion_name, new_cdn_url} ->
  case Repo.get_by(Champion, name: champion_name) do
    nil -> 
      IO.puts("⚠️  Champion '#{champion_name}' not found in database")
      failed_count = failed_count + 1
    champion ->
      changeset = Champion.changeset(champion, %{image_url: new_cdn_url})
      case Repo.update(changeset) do
        {:ok, _} -> 
          IO.puts("✅ #{champion_name} → #{new_cdn_url}")
          updated_count = updated_count + 1
        {:error, changeset} -> 
          IO.puts("❌ Failed to update #{champion_name}: #{inspect(changeset.errors)}")
          failed_count = failed_count + 1
      end
  end
end)

IO.puts("")
IO.puts("🎨 Champion CDN URL fix complete!")
IO.puts("📊 Updated: #{updated_count} champions")
IO.puts("⚠️  Failed: #{failed_count} champions")
IO.puts("🔗 All champions now use: https://cdn.communitydragon.org/latest/champion/[ID]/splash-art/centered")