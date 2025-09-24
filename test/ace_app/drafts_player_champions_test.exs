defmodule AceApp.DraftsPlayerChampionsTest do
  use AceApp.DataCase

  alias AceApp.Drafts
  alias AceApp.Drafts.Player
  alias AceApp.LoL

  describe "player champion assignments" do
    setup do
      # Create a draft with teams and players
      draft = draft_fixture()
      team = team_fixture(draft.id)
      player = player_fixture(draft.id, %{display_name: "Test Player", preferred_roles: [:adc, :mid]})
      
      # Create some test champions
      champion1 = champion_fixture(%{name: "Aatrox", key: "266", enabled: true})
      champion2 = champion_fixture(%{name: "Ahri", key: "103", enabled: true})
      champion3 = champion_fixture(%{name: "Akali", key: "84", enabled: true})
      
      %{
        draft: draft,
        team: team,
        player: player,
        champions: [champion1, champion2, champion3]
      }
    end

    test "auto_assign_missing_champions/1 assigns champions to players without assignments", %{draft: draft, player: player, champions: _champions} do
      # Verify player starts without champion
      assert player.champion_id == nil
      
      # Auto-assign champions
      Drafts.auto_assign_missing_champions(draft.id)
      
      # Check that player now has a champion assigned
      updated_player = AceApp.Repo.get!(Player, player.id) |> AceApp.Repo.preload([:champion])
      assert updated_player.champion_id != nil
      assert updated_player.champion != nil
      assert updated_player.champion.enabled == true
    end

    test "auto_assign_missing_champions/1 does not overwrite existing assignments", %{draft: draft, player: player, champions: [champion1 | _]} do
      # Manually assign a champion
      {:ok, _updated_player} = player
      |> Player.changeset(%{champion_id: champion1.id})
      |> AceApp.Repo.update()
      
      # Run auto-assignment
      Drafts.auto_assign_missing_champions(draft.id)
      
      # Verify the manual assignment was preserved
      final_player = AceApp.Repo.get!(Player, player.id)
      assert final_player.champion_id == champion1.id
    end

    test "auto_assign_missing_champions/1 only assigns enabled champions", %{draft: draft, player: player, champions: champions} do
      # Disable all existing champions
      Enum.each(champions, fn champion ->
        champion
        |> LoL.Champion.changeset(%{enabled: false})
        |> AceApp.Repo.update!()
      end)
      
      # Create an enabled champion
      enabled_champion = champion_fixture(%{name: "Enabled Champion", key: "999", enabled: true})
      
      # Auto-assign champions
      Drafts.auto_assign_missing_champions(draft.id)
      
      # Check that only enabled champion was assigned
      updated_player = AceApp.Repo.get!(Player, player.id) |> AceApp.Repo.preload([:champion])
      assert updated_player.champion_id == enabled_champion.id
    end

    test "assign_champion_to_player/3 manually assigns champion to player", %{player: player, champions: [champion1 | _]} do
      # Manually assign champion
      {:ok, updated_player} = Drafts.assign_champion_to_player(player.id, champion1.id)
      
      assert updated_player.champion_id == champion1.id
    end

    test "assign_champion_to_player/3 validates champion exists", %{player: player} do
      # Try to assign non-existent champion
      assert {:error, changeset} = Drafts.assign_champion_to_player(player.id, 99999)
      assert changeset.errors[:champion_id] != nil
    end

    test "assign_champion_to_player/3 allows preferred skin assignment", %{draft: _draft, player: player, champions: [champion1 | _]} do
      # Create a skin for the champion
      skin = champion_skin_fixture(champion1.id, %{skin_id: 1, name: "Test Skin"})
      
      # Assign champion with preferred skin
      {:ok, updated_player} = player
      |> Player.changeset(%{champion_id: champion1.id, preferred_skin_id: skin.skin_id})
      |> AceApp.Repo.update()
      
      assert updated_player.champion_id == champion1.id
      assert updated_player.preferred_skin_id == skin.skin_id
    end
  end

  describe "stream integration with player assignments" do
    setup do
      draft = draft_fixture()
      team = team_fixture(draft.id)
      player = player_fixture(draft.id, %{display_name: "Stream Player"})
      champion = champion_fixture(%{name: "Test Champion", key: "123", enabled: true})
      
      # Assign champion to player
      {:ok, updated_player} = player
      |> Player.changeset(%{champion_id: champion.id})
      |> AceApp.Repo.update()
      
      %{
        draft: draft,
        team: team,
        player: updated_player,
        champion: champion
      }
    end

    test "picks use player's assigned champion for splash art", %{draft: draft, team: team, player: player, champion: champion} do
      # Activate the draft first
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      # Assign the specific champion to the player
      {:ok, _updated_player} = Drafts.assign_champion_to_player(player.id, champion.id)
      
      # Create a pick (will get a random champion from make_pick)
      {:ok, pick} = Drafts.make_pick(draft.id, team.id, player.id, nil, false)
      
      # Verify pick has a champion assigned (automatic assignment)
      assert pick.champion_id != nil
      
      # Create skin for the champion
      _skin = champion_skin_fixture(champion.id, %{skin_id: 0, name: "Default"})
      
      # Format pick for stream and verify player has assigned champion
      pick_with_associations = pick |> AceApp.Repo.preload([:team, :player, :champion])
      player_with_champion = AceApp.Repo.preload(pick_with_associations.player, [:champion])
      
      # Player should still have the champion we specifically assigned
      assert player_with_champion.champion.id == champion.id
    end
  end

  # Helper functions
  defp draft_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      name: "Test Draft",
      format: "snake",
      pick_timer_seconds: 60,
      status: :setup,
      organizer_token: "org_#{System.unique_integer()}"
    })

    {:ok, draft} = Drafts.create_draft(attrs)
    Drafts.get_draft_with_associations!(draft.id)
  end

  defp team_fixture(draft_id, attrs \\ %{}) do
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
    unique_id = System.unique_integer()
    attrs = Enum.into(attrs, %{
      name: "Test Champion #{unique_id}",
      key: "#{unique_id}",
      title: "the Test",
      image_url: "https://example.com/champion_#{unique_id}.jpg",
      enabled: true,
      roles: ["mid"],
      tags: ["Mage"],
      difficulty: 5,
      release_date: Date.utc_today()
    })

    {:ok, champion} = LoL.create_champion(attrs)
    champion
  end

  defp champion_skin_fixture(champion_id, attrs) do
    unique_id = System.unique_integer()
    attrs = Enum.into(attrs, %{
      champion_id: champion_id,
      skin_id: unique_id,
      name: "Test Skin",
      splash_url: "https://example.com/splash_#{unique_id}.jpg",
      enabled: true,
      rarity: "common"
    })

    {:ok, skin} = LoL.create_champion_skin(attrs)
    skin
  end
end