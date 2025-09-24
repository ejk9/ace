defmodule AceApp.Drafts.SchemasTest do
  use AceApp.DataCase

  alias AceApp.Drafts.{
    Draft,
    Team,
    Player,
    PlayerAccount,
    Pick,
    ChatMessage,
    DraftEvent,
    SpectatorControls
  }

  describe "Draft" do
    @valid_attrs %{
      name: "Test Draft",
      format: :snake,
      pick_timer_seconds: 60,
      status: :setup
    }

    test "changeset with valid attributes" do
      changeset = Draft.changeset(%Draft{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset requires name" do
      changeset = Draft.changeset(%Draft{}, Map.delete(@valid_attrs, :name))
      assert "can't be blank" in errors_on(changeset).name
    end

    test "changeset uses default format when not provided" do
      attrs_without_format = Map.delete(@valid_attrs, :format)
      changeset = Draft.changeset(%Draft{}, attrs_without_format)
      draft = apply_changes(changeset)
      assert changeset.valid?
      assert draft.format == :snake
    end

    test "changeset validates format enum" do
      changeset = Draft.changeset(%Draft{}, %{@valid_attrs | format: :invalid_format})
      assert "is invalid" in errors_on(changeset).format
    end

    test "changeset validates status enum" do
      changeset = Draft.changeset(%Draft{}, %{@valid_attrs | status: :invalid_status})
      assert "is invalid" in errors_on(changeset).status
    end

    test "changeset validates pick_timer_seconds range" do
      changeset = Draft.changeset(%Draft{}, %{@valid_attrs | pick_timer_seconds: 5})
      assert "must be greater than or equal to 10" in errors_on(changeset).pick_timer_seconds

      changeset = Draft.changeset(%Draft{}, %{@valid_attrs | pick_timer_seconds: 400})
      assert "must be less than or equal to 300" in errors_on(changeset).pick_timer_seconds
    end

    test "changeset generates tokens on creation" do
      changeset = Draft.changeset(%Draft{}, @valid_attrs)

      apply_changes(changeset)
      |> then(fn draft ->
        assert is_binary(draft.organizer_token)
        assert is_binary(draft.spectator_token)
        assert String.length(draft.organizer_token) == 32
        assert String.length(draft.spectator_token) == 32
      end)
    end
  end

  describe "Team" do
    test "changeset with valid attributes" do
      changeset =
        Team.changeset(%Team{}, %{
          name: "Team Alpha",
          draft_id: 1,
          pick_order_position: 1
        })

      assert changeset.valid?
    end

    test "changeset requires name" do
      changeset = Team.changeset(%Team{}, %{draft_id: 1})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "changeset generates captain token" do
      changeset = Team.changeset(%Team{}, %{name: "Team Alpha", draft_id: 1})
      team = apply_changes(changeset)
      assert is_binary(team.captain_token)
      assert String.length(team.captain_token) == 32
    end
  end

  describe "Player" do
    test "changeset with valid attributes" do
      changeset =
        Player.changeset(%Player{}, %{
          display_name: "TestPlayer",
          preferred_roles: [:adc, :support],
          draft_id: 1
        })

      assert changeset.valid?
    end

    test "changeset requires display_name" do
      changeset = Player.changeset(%Player{}, %{draft_id: 1})
      assert "can't be blank" in errors_on(changeset).display_name
    end

    test "changeset validates preferred_roles enum" do
      changeset =
        Player.changeset(%Player{}, %{
          display_name: "TestPlayer",
          preferred_roles: [:invalid_role],
          draft_id: 1
        })

      refute changeset.valid?
    end

    test "changeset allows multiple preferred roles" do
      changeset =
        Player.changeset(%Player{}, %{
          display_name: "FlexPlayer",
          preferred_roles: [:top, :jungle, :mid, :adc, :support],
          draft_id: 1
        })

      assert changeset.valid?
    end
  end

  describe "PlayerAccount" do
    test "changeset with valid attributes" do
      changeset =
        PlayerAccount.changeset(%PlayerAccount{}, %{
          summoner_name: "TestSummoner",
          rank_tier: :gold,
          rank_division: :ii,
          server_region: :na1,
          player_id: 1
        })

      assert changeset.valid?
    end

    test "changeset requires summoner_name" do
      changeset = PlayerAccount.changeset(%PlayerAccount{}, %{player_id: 1})
      assert "can't be blank" in errors_on(changeset).summoner_name
    end

    test "changeset validates rank consistency" do
      # Master+ tiers shouldn't have divisions
      changeset =
        PlayerAccount.changeset(%PlayerAccount{}, %{
          summoner_name: "TestSummoner",
          rank_tier: :master,
          rank_division: :ii,
          server_region: :na1,
          player_id: 1
        })

      refute changeset.valid?
      assert "is not used for Master" in errors_on(changeset).rank_division

      # Lower tiers should have divisions if rank_tier is present
      changeset =
        PlayerAccount.changeset(%PlayerAccount{}, %{
          summoner_name: "TestSummoner",
          rank_tier: :gold,
          server_region: :na1,
          player_id: 1
        })

      refute changeset.valid?
      assert "is required for Gold" in errors_on(changeset).rank_division
    end

    test "changeset validates enum values" do
      changeset =
        PlayerAccount.changeset(%PlayerAccount{}, %{
          summoner_name: "TestSummoner",
          rank_tier: :invalid_tier,
          server_region: :na1,
          player_id: 1
        })

      refute changeset.valid?
    end
  end

  describe "Pick" do
    test "changeset with valid attributes" do
      changeset =
        Pick.changeset(%Pick{}, %{
          draft_id: 1,
          team_id: 1,
          player_id: 1,
          champion_id: 1,
          pick_number: 1,
          round_number: 1,
          picked_at: DateTime.utc_now()
        })

      assert changeset.valid?
    end

    test "changeset requires all fields" do
      changeset = Pick.changeset(%Pick{}, %{})
      assert "can't be blank" in errors_on(changeset).draft_id
      assert "can't be blank" in errors_on(changeset).team_id
      assert "can't be blank" in errors_on(changeset).player_id
      assert "can't be blank" in errors_on(changeset).pick_number
    end

    test "changeset validates pick_number is positive" do
      changeset =
        Pick.changeset(%Pick{}, %{
          draft_id: 1,
          team_id: 1,
          player_id: 1,
          pick_number: 0,
          picked_at: DateTime.utc_now()
        })

      assert "must be greater than 0" in errors_on(changeset).pick_number
    end
  end

  describe "ChatMessage" do
    test "changeset with valid attributes" do
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "Hello team!",
          sender_type: "captain",
          sender_name: "TestCaptain",
          draft_id: 1
        })

      assert changeset.valid?
    end

    test "changeset requires content" do
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          sender_type: "captain",
          sender_name: "TestCaptain",
          draft_id: 1
        })

      assert "can't be blank" in errors_on(changeset).content
    end

    test "changeset validates content length" do
      long_content = String.duplicate("a", 1001)

      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: long_content,
          sender_type: "captain",
          sender_name: "TestCaptain",
          draft_id: 1
        })

      assert "should be at most 1000 character(s)" in errors_on(changeset).content
    end

    test "changeset validates sender_name length" do
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "Hello",
          sender_type: "captain",
          sender_name: String.duplicate("a", 51),
          draft_id: 1
        })

      assert "should be at most 50 character(s)" in errors_on(changeset).sender_name
    end

    test "changeset validates enum values" do
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "Hello",
          sender_type: "invalid_sender",
          sender_name: "TestSender",
          draft_id: 1
        })

      assert "is invalid" in errors_on(changeset).sender_type

      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "Hello",
          sender_type: "captain",
          sender_name: "TestSender",
          message_type: "invalid_type",
          draft_id: 1
        })

      assert "is invalid" in errors_on(changeset).message_type
    end

    test "changeset validates team chat permissions" do
      # Non-captain/organizer trying to send team message
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "Hello team",
          sender_type: "spectator",
          sender_name: "TestSpectator",
          draft_id: 1,
          team_id: 1
        })

      assert "only captains, organizers, and team members can send team messages" in errors_on(changeset).sender_type

      # System message with team_id
      changeset =
        ChatMessage.changeset(%ChatMessage{}, %{
          content: "System message",
          sender_type: "system",
          sender_name: "System",
          draft_id: 1,
          team_id: 1
        })

      assert "system messages cannot be team-specific" in errors_on(changeset).team_id
    end
  end

  describe "DraftEvent" do
    test "changeset with valid attributes" do
      changeset =
        DraftEvent.changeset(%DraftEvent{}, %{
          event_type: "draft_created",
          event_data: %{organizer: "TestOrganizer"},
          draft_id: 1
        })

      assert changeset.valid?
    end

    test "changeset requires event_type and draft_id" do
      changeset = DraftEvent.changeset(%DraftEvent{}, %{})
      assert "can't be blank" in errors_on(changeset).event_type
      assert "can't be blank" in errors_on(changeset).draft_id
    end

    test "changeset validates event_type enum" do
      changeset =
        DraftEvent.changeset(%DraftEvent{}, %{
          event_type: "invalid_event",
          draft_id: 1
        })

      assert "is invalid" in errors_on(changeset).event_type
    end
  end

  describe "SpectatorControls" do
    test "changeset with valid attributes" do
      changeset =
        SpectatorControls.changeset(%SpectatorControls{}, %{
          draft_id: 1,
          show_player_notes: true,
          show_detailed_stats: false,
          show_match_history: true,
          stream_overlay_config: %{"theme" => "dark"}
        })

      assert changeset.valid?
    end

    test "changeset sets default values" do
      changeset = SpectatorControls.changeset(%SpectatorControls{}, %{draft_id: 1})
      controls = apply_changes(changeset)

      assert controls.show_player_notes == false
      assert controls.show_detailed_stats == true
      assert controls.show_match_history == false
      assert controls.stream_overlay_config == %{}
    end

    test "changeset requires draft_id" do
      changeset = SpectatorControls.changeset(%SpectatorControls{}, %{})
      assert "can't be blank" in errors_on(changeset).draft_id
    end
  end
end
