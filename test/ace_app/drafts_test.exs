defmodule AceApp.DraftsTest do
  use AceApp.DataCase

  alias AceApp.Drafts
  alias AceApp.Drafts.{Draft, Team, Player, Pick, ChatMessage, DraftEvent}
  alias AceApp.LoL

  describe "drafts" do
    @valid_draft_attrs %{
      name: "Test Draft",
      format: :snake,
      pick_timer_seconds: 60,
      status: :setup
    }
    @invalid_draft_attrs %{name: nil, format: nil}

    test "list_drafts/0 returns all drafts" do
      draft = draft_fixture()
      drafts = Drafts.list_drafts()
      assert length(drafts) == 1
      assert hd(drafts).id == draft.id
      assert hd(drafts).name == draft.name
    end

    test "get_draft!/1 returns the draft with given id" do
      draft = draft_fixture()
      assert Drafts.get_draft!(draft.id) == draft
    end

    test "create_draft/1 with valid data creates a draft" do
      assert {:ok, %Draft{} = draft} = Drafts.create_draft(@valid_draft_attrs)
      assert draft.name == "Test Draft"
      assert draft.format == :snake
      assert draft.pick_timer_seconds == 60
      assert draft.status == :setup
      assert is_binary(draft.organizer_token)
      assert is_binary(draft.spectator_token)
    end

    test "create_draft/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Drafts.create_draft(@invalid_draft_attrs)
    end

    test "update_draft/2 with valid data updates the draft" do
      draft = draft_fixture()
      update_attrs = %{name: "Updated Draft", status: :active}

      assert {:ok, %Draft{} = draft} = Drafts.update_draft(draft, update_attrs)
      assert draft.name == "Updated Draft"
      assert draft.status == :active
    end

    test "delete_draft/1 deletes the draft" do
      draft = draft_fixture()
      assert {:ok, %Draft{}} = Drafts.delete_draft(draft)
      assert_raise Ecto.NoResultsError, fn -> Drafts.get_draft!(draft.id) end
    end

    test "change_draft/1 returns a draft changeset" do
      draft = draft_fixture()
      assert %Ecto.Changeset{} = Drafts.change_draft(draft)
    end
  end

  describe "teams" do
    @valid_team_attrs %{"name" => "Test Team"}
    test "list_teams/1 returns all teams for a draft" do
      draft = draft_fixture()
      team = team_fixture(draft)
      assert Drafts.list_teams(draft.id) == [team]
    end

    test "create_team/2 with valid data creates a team" do
      draft = draft_fixture()
      assert {:ok, %Team{} = team} = Drafts.create_team(draft.id, @valid_team_attrs)
      assert team.name == "Test Team"
      assert team.draft_id == draft.id
      assert team.pick_order_position == 1
      assert is_binary(team.captain_token)
    end

    test "create_team/2 assigns sequential pick order positions" do
      draft = draft_fixture()

      {:ok, team1} = Drafts.create_team(draft.id, %{"name" => "Team 1"})
      {:ok, team2} = Drafts.create_team(draft.id, %{"name" => "Team 2"})

      assert team1.pick_order_position == 1
      assert team2.pick_order_position == 2
    end

    test "delete_team/1 deletes the team" do
      draft = draft_fixture()
      team = team_fixture(draft)
      assert {:ok, %Team{}} = Drafts.delete_team(team)
      assert Drafts.list_teams(draft.id) == []
    end

    test "reorder_teams/2 updates team pick order positions" do
      draft = draft_fixture()
      team1 = team_fixture(draft, %{"name" => "Team 1"})
      team2 = team_fixture(draft, %{"name" => "Team 2"})

      # Reorder teams
      {:ok, _} = Drafts.reorder_teams(draft.id, [team2.id, team1.id])

      # Verify new positions
      updated_teams = Drafts.list_teams(draft.id)
      team1_updated = Enum.find(updated_teams, &(&1.id == team1.id))
      team2_updated = Enum.find(updated_teams, &(&1.id == team2.id))

      assert team2_updated.pick_order_position == 1
      assert team1_updated.pick_order_position == 2
    end
  end

  describe "players" do
    @valid_player_attrs %{
      "display_name" => "TestPlayer",
      "preferred_roles" => [:adc, :mid]
    }
    test "list_players/1 returns all players for a draft" do
      draft = draft_fixture()
      player = player_fixture(draft)

      # list_players preloads player_accounts, so we need to account for that
      result = Drafts.list_players(draft.id)
      assert length(result) == 1

      returned_player = hd(result)
      assert returned_player.id == player.id
      assert returned_player.display_name == player.display_name
      assert returned_player.preferred_roles == player.preferred_roles
      # Empty list since no accounts created
      assert returned_player.player_accounts == []
    end

    test "create_player/2 with valid data creates a player" do
      draft = draft_fixture()
      assert {:ok, %Player{} = player} = Drafts.create_player(draft.id, @valid_player_attrs)
      assert player.display_name == "TestPlayer"
      assert player.preferred_roles == [:adc, :mid]
      assert player.draft_id == draft.id
    end

    test "list_available_players/1 excludes picked players" do
      draft = draft_fixture()
      team = team_fixture(draft)
      player1 = player_fixture(draft, %{"display_name" => "Player1"})
      player2 = player_fixture(draft, %{"display_name" => "Player2"})

      # Pick player1
      pick_fixture(draft, team, player1)

      available_players = Drafts.list_available_players(draft.id)
      assert length(available_players) == 1
      assert hd(available_players).id == player2.id
    end

    test "search_players/2 finds players by name" do
      draft = draft_fixture()
      player1 = player_fixture(draft, %{"display_name" => "Alice"})
      _player2 = player_fixture(draft, %{"display_name" => "Bob"})

      results = Drafts.search_players(draft.id, "alice")
      assert length(results) == 1
      assert hd(results).id == player1.id
    end

    test "list_available_players_by_role/2 filters by role" do
      draft = draft_fixture()

      adc_player =
        player_fixture(draft, %{"display_name" => "ADC Player", "preferred_roles" => [:adc]})

      _mid_player =
        player_fixture(draft, %{"display_name" => "Mid Player", "preferred_roles" => [:mid]})

      adc_players = Drafts.list_available_players_by_role(draft.id, :adc)
      assert length(adc_players) == 1
      assert hd(adc_players).id == adc_player.id
    end
  end

  describe "picks" do
    test "make_pick/5 creates a valid pick" do
      draft = draft_fixture(%{status: :active})
      team = team_fixture(draft)
      player = player_fixture(draft)
      champion = champion_fixture()

      assert {:ok, %Pick{} = pick} = Drafts.make_pick(draft.id, team.id, player.id, champion.id, DateTime.utc_now())
      assert pick.draft_id == draft.id
      assert pick.team_id == team.id
      assert pick.player_id == player.id
      assert pick.champion_id == champion.id
      assert pick.pick_number == 1
      assert pick.picked_at
    end

    test "make_pick/5 prevents picking same player twice" do
      draft = draft_fixture(%{status: :active})
      team1 = team_fixture(draft)
      team2 = team_fixture(draft, %{"name" => "Team 2"})
      player = player_fixture(draft)
      champion1 = champion_fixture()
      champion2 = champion_fixture(%{name: "Ezreal", key: "Ezreal"})

      # First pick succeeds
      assert {:ok, _pick} = Drafts.make_pick(draft.id, team1.id, player.id, champion1.id, DateTime.utc_now())

      # Second pick fails
      assert {:error, :player_already_picked} = Drafts.make_pick(draft.id, team2.id, player.id, champion2.id, DateTime.utc_now())
    end

    test "make_pick/5 increments pick numbers" do
      draft = draft_fixture(%{status: :active})
      team = team_fixture(draft)
      player1 = player_fixture(draft, %{"display_name" => "Player1"})
      player2 = player_fixture(draft, %{"display_name" => "Player2"})
      
      # Create a champion for the picks
      {:ok, champion} = LoL.create_champion(%{
        name: "Jinx",
        key: "Jinx",
        title: "The Loose Cannon",
        tags: ["Marksman"],
        resource_type: "Mana",
        attack_type: "Ranged",
        primary_role: :adc,
        secondary_role: nil,
        enabled: true,
        image_url: "https://example.com/jinx.jpg",
        roles: ["adc"],
        difficulty: 5,
        release_date: ~D[2013-10-10]
      })

      {:ok, pick1} = Drafts.make_pick(draft.id, team.id, player1.id, champion.id)
      {:ok, pick2} = Drafts.make_pick(draft.id, team.id, player2.id, champion.id)

      assert pick1.pick_number == 1
      assert pick2.pick_number == 2
    end
  end

  describe "chat messages" do
    test "send_chat_message/5 creates a global message" do
      draft = draft_fixture()

      assert {:ok, %ChatMessage{} = message} =
               Drafts.send_chat_message(draft.id, "captain", "TestCaptain", "Hello everyone!")

      assert message.content == "Hello everyone!"
      assert message.sender_type == "captain"
      assert message.sender_name == "TestCaptain"
      assert message.draft_id == draft.id
      assert is_nil(message.team_id)
    end

    test "send_team_chat_message/6 creates a team-specific message" do
      draft = draft_fixture()
      team = team_fixture(draft)

      assert {:ok, %ChatMessage{} = message} =
               Drafts.send_team_chat_message(
                 draft.id,
                 team.id,
                 "captain",
                 "TestCaptain",
                 "Team strategy!"
               )

      assert message.content == "Team strategy!"
      assert message.team_id == team.id
    end

    test "list_chat_messages/1 returns global messages only" do
      draft = draft_fixture()
      team = team_fixture(draft)

      {:ok, global_msg} = Drafts.send_chat_message(draft.id, "captain", "Cap1", "Global message")

      {:ok, _team_msg} =
        Drafts.send_team_chat_message(draft.id, team.id, "captain", "Cap1", "Team message")

      global_messages = Drafts.list_chat_messages(draft.id)
      assert length(global_messages) == 1
      assert hd(global_messages).id == global_msg.id
    end

    test "list_team_chat_messages/2 returns team messages only" do
      draft = draft_fixture()
      team = team_fixture(draft)

      {:ok, _global_msg} = Drafts.send_chat_message(draft.id, "captain", "Cap1", "Global message")

      {:ok, team_msg} =
        Drafts.send_team_chat_message(draft.id, team.id, "captain", "Cap1", "Team message")

      team_messages = Drafts.list_team_chat_messages(draft.id, team.id)
      assert length(team_messages) == 1
      assert hd(team_messages).id == team_msg.id
    end
  end

  describe "draft events" do
    test "log_draft_event/3 creates an audit event" do
      draft = draft_fixture()

      assert {:ok, %DraftEvent{} = event} =
               Drafts.log_draft_event(draft.id, "draft_started", %{organizer: "TestOrganizer"})

      assert event.event_type == "draft_started"
      assert event.event_data == %{organizer: "TestOrganizer"}
      assert event.draft_id == draft.id
    end

    test "get_draft_timeline/1 returns formatted events" do
      draft = draft_fixture()

      {:ok, _event1} = Drafts.log_draft_event(draft.id, "draft_created", %{})
      {:ok, _event2} = Drafts.log_draft_event(draft.id, "draft_started", %{})

      timeline = Drafts.get_draft_timeline(draft.id)
      assert length(timeline) == 2

      [first_event | _] = timeline
      assert first_event.event_type == "draft_created"
      assert first_event.description == "Draft was created"
      assert first_event.timestamp
    end
  end

  describe "statistics" do
    test "get_player_stats/1 returns player counts by role" do
      draft = draft_fixture()

      _adc_player =
        player_fixture(draft, %{"display_name" => "ADC1", "preferred_roles" => [:adc]})

      _mid_player =
        player_fixture(draft, %{"display_name" => "Mid1", "preferred_roles" => [:mid]})

      _flex_player =
        player_fixture(draft, %{"display_name" => "Flex", "preferred_roles" => [:adc, :mid]})

      stats = Drafts.get_player_stats(draft.id)

      assert stats.total_players == 3
      assert stats.available_players == 3
      assert stats.players_by_role[:adc] == 2
      assert stats.players_by_role[:mid] == 2
    end

    test "get_chat_stats/1 returns message statistics" do
      draft = draft_fixture()
      team = team_fixture(draft)

      {:ok, _msg1} = Drafts.send_chat_message(draft.id, "captain", "Cap1", "Global 1")
      {:ok, _msg2} = Drafts.send_chat_message(draft.id, "captain", "Cap1", "Global 2")

      {:ok, _msg3} =
        Drafts.send_team_chat_message(draft.id, team.id, "captain", "Cap1", "Team message")

      stats = Drafts.get_chat_stats(draft.id)

      assert stats.total_messages == 3
      assert stats.global_messages == 2
      assert stats.team_messages == 1
      assert stats.unique_senders == 1
    end
  end

  # Test helper functions
  defp draft_fixture(attrs \\ %{}) do
    {:ok, draft} =
      attrs
      |> Enum.into(@valid_draft_attrs)
      |> Drafts.create_draft()

    draft
  end

  defp team_fixture(draft, attrs \\ %{}) do
    {:ok, team} =
      attrs
      |> Enum.into(%{"name" => "Test Team"})
      |> then(&Drafts.create_team(draft.id, &1))

    team
  end

  defp player_fixture(draft, attrs \\ %{}) do
    {:ok, player} =
      attrs
      |> Enum.into(@valid_player_attrs)
      |> then(&Drafts.create_player(draft.id, &1))

    player
  end

  defp pick_fixture(draft, team, player) do
    # For testing, we'll bypass the turn validation
    champion = champion_fixture()
    {:ok, pick} =
      %Pick{}
      |> Pick.changeset(%{
        draft_id: draft.id,
        team_id: team.id,
        player_id: player.id,
        champion_id: champion.id,
        pick_number: 1,
        round_number: 1,
        picked_at: DateTime.utc_now()
      })
      |> Repo.insert()

    pick
  end

  defp champion_fixture(attrs \\ %{}) do
    {:ok, champion} = LoL.create_champion(
      attrs
      |> Enum.into(%{
        name: "Jinx",
        key: "Jinx",
        title: "The Loose Cannon",
        tags: ["Marksman"],
        resource_type: "Mana",
        attack_type: "Ranged",
        primary_role: :adc,
        secondary_role: nil,
        enabled: true,
        image_url: "https://example.com/jinx.jpg",
        roles: ["adc"],
        difficulty: 5,
        release_date: ~D[2013-10-10]
      })
    )
    champion
  end
end
