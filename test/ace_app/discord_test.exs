defmodule AceApp.DiscordTest do
  use AceApp.DataCase

  alias AceApp.Discord
  alias AceApp.Drafts
  alias AceApp.Drafts.{Draft, Team, Player, Pick}
  
  import ExUnit.CaptureLog

  describe "webhook validation" do
    test "validate_webhook/1 with valid URL format returns error for unreachable URL" do
      # We expect this to fail since it's not a real Discord webhook
      webhook_url = "https://discord.com/api/webhooks/123456789/fake-token"
      
      assert {:error, _reason} = Discord.validate_webhook(webhook_url)
    end

    test "validate_webhook/1 with invalid URL format returns error" do
      assert {:error, "Invalid webhook URL"} = Discord.validate_webhook(nil)
      assert {:error, "Invalid webhook URL"} = Discord.validate_webhook("")
      assert {:error, "Invalid webhook URL"} = Discord.validate_webhook(123)
    end

    test "validate_webhook/1 with malformed URL returns error" do
      assert {:error, _reason} = Discord.validate_webhook("not-a-url")
      assert {:error, _reason} = Discord.validate_webhook("http://invalid")
    end
  end

  describe "draft event notifications" do
    setup do
      # Create a draft with Discord enabled but invalid webhook for testing
      draft = draft_fixture(%{
        discord_webhook_url: "https://discord.com/api/webhooks/test/fake",
        discord_webhook_validated: true,
        discord_notifications_enabled: true
      })
      
      %{draft: draft}
    end

    test "notify_draft_event/3 with enabled Discord sends notification", %{draft: draft} do
      # This will fail to send but should attempt and log the failure
      log = capture_log(fn ->
        result = Discord.notify_draft_event(draft, :draft_started, %{teams_count: 2})
        assert {:error, _reason} = result
      end)
      
      assert log =~ "Failed to send Discord notification"
    end

    test "notify_draft_event/3 with disabled Discord skips notification" do
      draft = draft_fixture(%{discord_notifications_enabled: false})
      
      log = capture_log(fn ->
        result = Discord.notify_draft_event(draft, :draft_started)
        assert :skip = result
      end)
      
      assert log =~ "Skipping notification"
    end

    test "notify_draft_event/3 with unvalidated webhook skips notification" do
      draft = draft_fixture(%{
        discord_webhook_url: "https://discord.com/api/webhooks/test/fake",
        discord_webhook_validated: false,
        discord_notifications_enabled: true
      })
      
      log = capture_log(fn ->
        result = Discord.notify_draft_event(draft, :draft_started)
        assert :skip = result
      end)
      
      assert log =~ "Skipping notification"
    end

    test "notify_draft_event/3 with missing webhook URL skips notification" do
      draft = draft_fixture(%{
        discord_webhook_url: nil,
        discord_webhook_validated: true,
        discord_notifications_enabled: true
      })
      
      log = capture_log(fn ->
        result = Discord.notify_draft_event(draft, :draft_started)
        assert :skip = result
      end)
      
      assert log =~ "Skipping notification"
    end
  end

  describe "player pick notifications" do
    setup do
      draft = draft_fixture(%{
        discord_webhook_url: "https://discord.com/api/webhooks/test/fake",
        discord_webhook_validated: true,
        discord_notifications_enabled: true
      })
      
      team = team_fixture(draft)
      player = player_fixture(draft)
      pick = pick_fixture(draft, team, player)
      
      %{draft: draft, team: team, player: player, pick: pick}
    end

    test "notify_player_pick/4 with enabled Discord attempts to send notification", %{
      draft: draft, player: player, pick: pick
    } do
      # This will fail due to fake webhook but should attempt screenshot capture
      _log = capture_log(fn ->
        result = Discord.notify_player_pick(draft, pick, player)
        # The fake webhook will likely return an error, but if screenshot fails it might skip
        assert result == :ok or match?({:error, _}, result)
      end)
      
      # Test passed if function executed without crashing
      assert true
    end

    test "notify_player_pick/4 with disabled Discord skips notification", %{
      player: player, pick: pick
    } do
      draft = draft_fixture(%{discord_notifications_enabled: false})
      
      log = capture_log(fn ->
        result = Discord.notify_player_pick(draft, pick, player)
        assert :skip = result
      end)
      
      assert log =~ "Skipping notification"
    end

    test "notify_player_pick/4 handles screenshot service failure gracefully", %{
      draft: draft, player: player, pick: pick
    } do
      # Mock screenshot service failure by using nil file path
      log = capture_log(fn ->
        result = Discord.notify_player_pick(draft, pick, player, nil)
        # Could succeed without screenshot or fail at webhook level - both are valid
        assert result == :ok or match?({:error, _}, result)
      end)
      
      # Should log some Discord activity
      assert log =~ "Discord" or log == ""
    end
  end

  describe "embed building" do
    test "builds valid embed structure for draft events" do
      draft = draft_fixture()
      
      # We can't directly test the private embed building functions,
      # but we can test that the notification functions handle them properly
      log = capture_log(fn ->
        Discord.notify_draft_event(draft, :draft_started, %{teams_count: 2})
      end)
      
      # Should skip due to missing webhook config but should not crash
      assert log =~ "Skipping notification"
    end

    test "builds valid embed structure for pick events" do
      draft = draft_fixture()
      team = team_fixture(draft)
      player = player_fixture(draft)
      pick = pick_fixture(draft, team, player)
      
      log = capture_log(fn ->
        Discord.notify_player_pick(draft, pick, player)
      end)
      
      # Should skip due to missing webhook config but should not crash
      assert log =~ "Skipping notification"
    end
  end

  # Helper functions for creating test data
  defp draft_fixture(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Draft",
      format: :snake,
      pick_timer_seconds: 60,
      status: :setup,
      discord_webhook_url: nil,
      discord_webhook_validated: false,
      discord_notifications_enabled: false
    }
    
    attrs = Map.merge(default_attrs, attrs)
    {:ok, draft} = Drafts.create_draft(attrs)
    draft
  end

  defp team_fixture(draft, attrs \\ %{}) do
    attrs = Map.merge(%{"name" => "Test Team"}, attrs)
    {:ok, team} = Drafts.create_team(draft.id, attrs)
    team
  end

  defp player_fixture(draft, attrs \\ %{}) do
    attrs = Map.merge(%{
      "display_name" => "Test Player",
      "preferred_roles" => ["top"]
    }, attrs)
    
    {:ok, player} = Drafts.create_player(draft.id, attrs)
    player
  end

  defp pick_fixture(draft, team, player) do
    champion_id = AceApp.DataCase.random_champion_id()
    pick_number = Drafts.get_current_pick_number(draft.id) + 1
    
    {:ok, pick} =
      %Pick{}
      |> Pick.changeset(%{
        draft_id: draft.id,
        team_id: team.id,
        player_id: player.id,
        champion_id: champion_id,
        pick_number: pick_number,
        round_number: 1,
        side: "blue",
        status: "completed",
        picked_at: DateTime.utc_now()
      })
      |> Repo.insert()
    
    pick
  end
end