defmodule AceApp.LoLChampionTest do
  use AceApp.DataCase

  alias AceApp.LoL

  @valid_champion_attrs %{
    name: "Jinx",
    key: "Jinx",
    title: "The Loose Cannon",
    image_url: "https://cdn.communitydragon.org/latest/champion/222/square",
    roles: ["adc"],
    tags: ["marksman"],
    difficulty: 6,
    enabled: true,
    release_date: ~D[2013-10-10]
  }

  describe "roles/0" do
    test "returns valid LoL roles" do
      roles = LoL.roles()
      assert :top in roles
      assert :jungle in roles
      assert :mid in roles
      assert :adc in roles
      assert :support in roles
      assert length(roles) == 5
    end
  end

  describe "valid_roles?/1" do
    test "returns true for valid roles list" do
      assert LoL.valid_roles?([:top, :jungle])
      assert LoL.valid_roles?([:adc])
      assert LoL.valid_roles?([])
    end

    test "returns false for invalid roles" do
      refute LoL.valid_roles?([:invalid_role])
      refute LoL.valid_roles?([:top, :invalid])
      refute LoL.valid_roles?("not a list")
      refute LoL.valid_roles?(nil)
    end
  end

  describe "champion database functions" do
    setup do
      # Create test champions
      jinx = champion_fixture(@valid_champion_attrs)

      garen =
        champion_fixture(%{
          name: "Garen",
          key: "Garen",
          title: "The Might of Demacia",
          image_url: "https://cdn.communitydragon.org/latest/champion/86/square",
          roles: ["top"],
          tags: ["fighter", "tank"],
          difficulty: 3,
          enabled: true,
          release_date: ~D[2010-02-21]
        })

      yasuo_disabled =
        champion_fixture(%{
          name: "Yasuo",
          key: "Yasuo",
          title: "The Unforgiven",
          image_url: "https://cdn.communitydragon.org/latest/champion/157/square",
          roles: ["mid"],
          tags: ["fighter", "assassin"],
          difficulty: 10,
          enabled: false,
          release_date: ~D[2013-12-13]
        })

      %{jinx: jinx, garen: garen, yasuo_disabled: yasuo_disabled}
    end

    test "list_champions/0 returns all champions", %{
      jinx: _jinx,
      garen: _garen,
      yasuo_disabled: _yasuo
    } do
      champions = LoL.list_champions()
      assert length(champions) == 3

      champion_names = Enum.map(champions, & &1.name)
      # Ordered by name
      assert "Garen" in champion_names
      assert "Jinx" in champion_names
      assert "Yasuo" in champion_names
    end

    test "list_enabled_champions/0 returns only enabled champions", %{jinx: _jinx, garen: _garen} do
      champions = LoL.list_enabled_champions()
      assert length(champions) == 2

      champion_names = Enum.map(champions, & &1.name)
      assert "Garen" in champion_names
      assert "Jinx" in champion_names
      refute "Yasuo" in champion_names
    end

    test "list_champions_by_role/1 returns champions for specific role", %{
      jinx: jinx,
      garen: garen
    } do
      adc_champions = LoL.list_champions_by_role(:adc)
      assert length(adc_champions) == 1
      assert hd(adc_champions).id == jinx.id

      top_champions = LoL.list_champions_by_role(:top)
      assert length(top_champions) == 1
      assert hd(top_champions).id == garen.id

      jungle_champions = LoL.list_champions_by_role(:jungle)
      assert length(jungle_champions) == 0
    end

    test "search_champions/1 finds champions by name", %{jinx: jinx} do
      results = LoL.search_champions("jinx")
      assert length(results) == 1
      assert hd(results).id == jinx.id

      # Case insensitive
      results = LoL.search_champions("JINX")
      assert length(results) == 1
      assert hd(results).id == jinx.id
    end

    test "search_champions/1 finds champions by title", %{garen: garen} do
      results = LoL.search_champions("might")
      assert length(results) == 1
      assert hd(results).id == garen.id

      results = LoL.search_champions("demacia")
      assert length(results) == 1
      assert hd(results).id == garen.id
    end

    test "get_champion!/1 returns champion with given id", %{jinx: jinx} do
      found_champion = LoL.get_champion!(jinx.id)
      assert found_champion.id == jinx.id
      assert found_champion.name == "Jinx"
    end

    test "get_champion_by_name/1 returns champion with given name", %{jinx: jinx} do
      found_champion = LoL.get_champion_by_name("Jinx")
      assert found_champion.id == jinx.id
      assert found_champion.name == "Jinx"

      nil_result = LoL.get_champion_by_name("NonexistentChampion")
      assert nil_result == nil
    end

    test "create_champion/1 creates a new champion" do
      attrs = %{
        name: "Akali",
        key: "Akali",
        title: "The Rogue Assassin",
        image_url: "https://cdn.communitydragon.org/latest/champion/84/square",
        roles: ["mid"],
        tags: ["assassin"],
        difficulty: 7,
        enabled: true,
        release_date: ~D[2010-05-11]
      }

      assert {:ok, champion} = LoL.create_champion(attrs)
      assert champion.name == "Akali"
      assert champion.enabled == true
    end

    test "update_champion/2 updates existing champion", %{jinx: jinx} do
      update_attrs = %{difficulty: 8, enabled: false}

      assert {:ok, updated_champion} = LoL.update_champion(jinx, update_attrs)
      assert updated_champion.difficulty == 8
      assert updated_champion.enabled == false
      # Unchanged
      assert updated_champion.name == "Jinx"
    end

    test "toggle_champion_enabled/1 toggles enabled status", %{jinx: jinx} do
      assert jinx.enabled == true

      assert {:ok, toggled} = LoL.toggle_champion_enabled(jinx)
      assert toggled.enabled == false

      assert {:ok, toggled_again} = LoL.toggle_champion_enabled(toggled)
      assert toggled_again.enabled == true
    end

    test "delete_champion/1 deletes the champion", %{jinx: jinx} do
      assert {:ok, _} = LoL.delete_champion(jinx)
      assert_raise Ecto.NoResultsError, fn -> LoL.get_champion!(jinx.id) end
    end

    test "get_champions_count_by_role/0 returns counts by role", %{jinx: _jinx, garen: _garen} do
      counts = LoL.get_champions_count_by_role()

      assert counts[:adc] == 1
      assert counts[:top] == 1
      # Yasuo is disabled
      assert counts[:mid] == 0
      assert counts[:jungle] == 0
      assert counts[:support] == 0
    end

    test "get_champion_stats/0 returns champion statistics" do
      stats = LoL.get_champion_stats()

      assert stats.total == 3
      assert stats.enabled == 2
      assert stats.disabled == 1
      assert is_map(stats.by_role)
      assert stats.by_role[:adc] == 1
    end
  end

  # Test helper
  defp champion_fixture(attrs) do
    {:ok, champion} =
      attrs
      |> Enum.into(@valid_champion_attrs)
      |> LoL.create_champion()

    champion
  end
end
