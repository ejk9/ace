defmodule AceAppWeb.StreamControllerPrecacheTest do
  use AceAppWeb.ConnCase

  alias AceApp.Drafts
  alias AceApp.LoL

  describe "overlay endpoint with precache_images" do
    setup do
      # Create draft with teams and players
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Team Alpha", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Team Beta", pick_order_position: 2})
      
      # Create champions
      champion1 = champion_fixture(%{name: "Aatrox", key: "266"})
      champion2 = champion_fixture(%{name: "Ahri", key: "103"})
      
      # Create players with champion assignments
      player1 = player_fixture(draft.id, %{display_name: "Player 1", champion_id: champion1.id})
      player2 = player_fixture(draft.id, %{display_name: "Player 2", champion_id: champion2.id})
      player3 = player_fixture(draft.id, %{display_name: "Player 3"}) # No champion assigned
      
      # Create skins for champions
      skin1 = champion_skin_fixture(champion1.id, %{skin_id: 266000, name: "Default Aatrox"})
      skin2 = champion_skin_fixture(champion2.id, %{skin_id: 103001, name: "Midnight Ahri"})
      
      %{
        draft: draft,
        teams: [team1, team2],
        players: [player1, player2, player3],
        champions: [champion1, champion2],
        skins: [skin1, skin2]
      }
    end

    test "GET /stream/:id/overlay.json includes precache_images field", %{conn: conn, draft: draft} do
      conn = get(conn, "/stream/#{draft.id}/overlay.json")
      
      assert %{
        "precache_images" => precache_images,
        "all_picks" => _all_picks,
        "teams" => _teams,
        "draft" => _draft_info
      } = json_response(conn, 200)
      
      # Should be an array
      assert is_list(precache_images)
    end

    test "precache_images includes players with assigned champions", %{conn: conn, draft: draft, players: [_player1, _player2, _player3]} do
      conn = get(conn, "/stream/#{draft.id}/overlay.json")
      response = json_response(conn, 200)
      
      precache_images = response["precache_images"]
      
      # Should have 2 entries (player1 and player2 have champions, player3 doesn't)
      assert length(precache_images) == 2
      
      # Find entries by player name
      player1_entry = Enum.find(precache_images, &(&1["player_name"] == "Player 1"))
      player2_entry = Enum.find(precache_images, &(&1["player_name"] == "Player 2"))
      
      assert player1_entry != nil
      assert player2_entry != nil
      
      # Verify champion data structure
      assert %{
        "champion" => %{
          "id" => _id,
          "name" => champion_name,
          "title" => _title,
          "splash_url" => splash_url,
          "skin_name" => _skin_name
        }
      } = player1_entry
      
      assert champion_name == "Aatrox"
      assert String.contains?(splash_url, "cdn.communitydragon.org")
      assert String.contains?(splash_url, "splash-art/centered/skin")
    end

    test "splash URLs use correct skin offset calculation", %{conn: conn, draft: draft} do
      conn = get(conn, "/stream/#{draft.id}/overlay.json")
      response = json_response(conn, 200)
      
      precache_images = response["precache_images"]
      
      # Find Aatrox entry (skin_id: 266000 should become offset 0)
      aatrox_entry = Enum.find(precache_images, fn item ->
        item["champion"]["name"] == "Aatrox"
      end)
      
      assert aatrox_entry != nil
      splash_url = aatrox_entry["champion"]["splash_url"]
      
      # Should use champion key 266 and skin offset 0 (266000 % 1000 = 0)
      assert String.contains?(splash_url, "champion/266/splash-art/centered/skin/0")
    end

    test "precache_images excludes players without champion assignments", %{conn: conn, draft: draft} do
      conn = get(conn, "/stream/#{draft.id}/overlay.json")
      response = json_response(conn, 200)
      
      precache_images = response["precache_images"]
      
      # Should not include Player 3 (no champion assigned)
      player3_entry = Enum.find(precache_images, &(&1["player_name"] == "Player 3"))
      assert player3_entry == nil
    end

    test "all_picks and precache_images work together for complete image list", %{conn: conn, draft: draft, teams: [team1, _team2], players: [player1, _player2, _player3], champions: [champion1, _champion2]} do
      # Make a pick to have both all_picks and precache_images data
      {:ok, _pick} = Drafts.make_pick(draft.id, team1.id, player1.id, champion1.id, false)
      
      conn = get(conn, "/stream/#{draft.id}/overlay.json")
      response = json_response(conn, 200)
      
      all_picks = response["all_picks"]
      precache_images = response["precache_images"]
      
      # Should have pick data
      assert length(all_picks) == 1
      # Should still have precache data for all assigned champions
      assert length(precache_images) >= 1
      
      # Verify both contain splash URL data
      pick = List.first(all_picks)
      assert pick["champion"]["splash_url"] != nil
      
      precache_item = List.first(precache_images)
      assert precache_item["champion"]["splash_url"] != nil
    end
  end

  # Helper functions
  defp draft_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      name: "Test Draft",
      format: "snake",
      pick_timer_seconds: 60,
      status: :active,
      organizer_token: "org_#{System.unique_integer()}"
    })

    {:ok, draft} = Drafts.create_draft(attrs)
    draft
  end

  defp team_fixture(draft_id, attrs) do
    attrs = Enum.into(attrs, %{
      name: "Test Team",
      pick_order_position: 1,
      captain_token: "cap_#{System.unique_integer()}"
    })

    {:ok, team} = Drafts.create_team(draft_id, attrs)
    team
  end

  defp player_fixture(draft_id, attrs) do
    attrs = Enum.into(attrs, %{
      display_name: "Test Player #{System.unique_integer()}",
      preferred_roles: [:adc]
    })

    {:ok, player} = Drafts.create_player(draft_id, attrs)
    player
  end

  defp champion_fixture(attrs) do
    attrs = Enum.into(attrs, %{
      name: "Test Champion #{System.unique_integer()}",
      key: "#{System.unique_integer()}",
      title: "the Test",
      image_url: "https://ddragon.leagueoflegends.com/cdn/test/champion.png",
      enabled: true,
      roles: ["mid"],
      tags: ["Mage"],
      difficulty: 5,
      release_date: ~D[2023-01-01]
    })

    {:ok, champion} = LoL.create_champion(attrs)
    champion
  end

  defp champion_skin_fixture(champion_id, attrs) do
    attrs = Enum.into(attrs, %{
      champion_id: champion_id,
      skin_id: System.unique_integer(),
      name: "Test Skin",
      splash_url: "https://cdn.communitydragon.org/latest/champion/#{champion_id}/splash-art/test.png",
      enabled: true,
      rarity: "common"
    })

    {:ok, skin} = LoL.create_champion_skin(attrs)
    skin
  end
end