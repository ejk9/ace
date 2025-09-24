# Update champion image URLs to use CommunityDragon CDN
import Ecto.Query
alias AceApp.Repo

# Champion ID to CommunityDragon CDN URL mapping
champion_urls = %{
  "Jinx" => "https://cdn.communitydragon.org/latest/champion/222/square",
  "Garen" => "https://cdn.communitydragon.org/latest/champion/86/square",
  "Yasuo" => "https://cdn.communitydragon.org/latest/champion/157/square",
  "Ahri" => "https://cdn.communitydragon.org/latest/champion/103/square",
  "Lee Sin" => "https://cdn.communitydragon.org/latest/champion/64/square",
  "Thresh" => "https://cdn.communitydragon.org/latest/champion/412/square",
  "Ezreal" => "https://cdn.communitydragon.org/latest/champion/81/square",
  "Zed" => "https://cdn.communitydragon.org/latest/champion/238/square",
  "Graves" => "https://cdn.communitydragon.org/latest/champion/104/square",
  "Darius" => "https://cdn.communitydragon.org/latest/champion/122/square",
  "Janna" => "https://cdn.communitydragon.org/latest/champion/40/square",
  "Vayne" => "https://cdn.communitydragon.org/latest/champion/67/square",
  "Fiora" => "https://cdn.communitydragon.org/latest/champion/114/square",
  "Caitlyn" => "https://cdn.communitydragon.org/latest/champion/51/square",
  "Kha'Zix" => "https://cdn.communitydragon.org/latest/champion/121/square",
  "Ornn" => "https://cdn.communitydragon.org/latest/champion/516/square",
  "Leona" => "https://cdn.communitydragon.org/latest/champion/89/square",
  "Kai'Sa" => "https://cdn.communitydragon.org/latest/champion/145/square",
  "Orianna" => "https://cdn.communitydragon.org/latest/champion/61/square",
  "Kindred" => "https://cdn.communitydragon.org/latest/champion/203/square",
  
  # Additional champions that might be in our seed data
  "Lux" => "https://cdn.communitydragon.org/latest/champion/99/square",
  "Katarina" => "https://cdn.communitydragon.org/latest/champion/55/square",
  "Azir" => "https://cdn.communitydragon.org/latest/champion/268/square",
  "Elise" => "https://cdn.communitydragon.org/latest/champion/60/square",
  "Morgana" => "https://cdn.communitydragon.org/latest/champion/25/square"
}

# Update each champion's image URL
updated_count = 0
Enum.each(champion_urls, fn {champion_name, new_url} ->
  case Repo.get_by(AceApp.LoL.Champion, name: champion_name) do
    nil -> 
      IO.puts("Champion '#{champion_name}' not found")
    champion ->
      champion
      |> AceApp.LoL.Champion.changeset(%{image_url: new_url})
      |> Repo.update()
      |> case do
        {:ok, _} -> 
          IO.puts("Updated #{champion_name} with CDN URL")
          updated_count = updated_count + 1
        {:error, changeset} -> 
          IO.puts("Failed to update #{champion_name}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("Champion CDN URL update complete! Updated #{updated_count} champions.")