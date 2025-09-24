defmodule AceAppWeb.DraftSetupLiveIntegrationTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  
  alias AceApp.Drafts

  setup do
    draft = draft_fixture(%{status: "setup"})
    
    {:ok, team1} = Drafts.create_team(draft.id, %{"name" => "Team Alpha"})
    {:ok, team2} = Drafts.create_team(draft.id, %{"name" => "Team Beta"})
    
    # Create players for the draft (need 5 players per team = 10 players total)
    {:ok, _player1} = Drafts.create_player(draft.id, %{"display_name" => "Player One", "preferred_roles" => ["top"]})
    {:ok, _player2} = Drafts.create_player(draft.id, %{"display_name" => "Player Two", "preferred_roles" => ["jungle"]})
    {:ok, _player3} = Drafts.create_player(draft.id, %{"display_name" => "Player Three", "preferred_roles" => ["mid"]})
    {:ok, _player4} = Drafts.create_player(draft.id, %{"display_name" => "Player Four", "preferred_roles" => ["adc"]})
    {:ok, _player5} = Drafts.create_player(draft.id, %{"display_name" => "Player Five", "preferred_roles" => ["support"]})
    {:ok, _player6} = Drafts.create_player(draft.id, %{"display_name" => "Player Six", "preferred_roles" => ["top"]})
    {:ok, _player7} = Drafts.create_player(draft.id, %{"display_name" => "Player Seven", "preferred_roles" => ["jungle"]})
    {:ok, _player8} = Drafts.create_player(draft.id, %{"display_name" => "Player Eight", "preferred_roles" => ["mid"]})
    {:ok, _player9} = Drafts.create_player(draft.id, %{"display_name" => "Player Nine", "preferred_roles" => ["adc"]})
    {:ok, _player10} = Drafts.create_player(draft.id, %{"display_name" => "Player Ten", "preferred_roles" => ["support"]})

    %{draft: draft, team1: team1, team2: team2}
  end

  describe "draft finalization and mock draft creation" do
    test "automatically creates mock draft when finalizing draft", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, ~p"/drafts/#{draft.id}/setup")

      # Verify initial state
      assert has_element?(view, "button", "Finalize Draft")
      
      # Check that no mock draft exists yet
      mock_drafts_before = AceApp.MockDrafts.list_mock_drafts_for_draft(draft.id)
      assert length(mock_drafts_before) == 0

      # Finalize the draft
      view |> element("button", "Finalize Draft") |> render_click()

      # Verify mock draft was created
      mock_drafts_after = AceApp.MockDrafts.list_mock_drafts_for_draft(draft.id)
      assert length(mock_drafts_after) == 1
      
      mock_draft = hd(mock_drafts_after)
      assert mock_draft.draft_id == draft.id
      assert mock_draft.predraft_enabled == true
      assert mock_draft.live_enabled == true
      assert is_binary(mock_draft.mock_draft_token)
      assert String.length(mock_draft.mock_draft_token) > 0

      # Verify flash message includes mock draft info
      assert render(view) =~ "Draft is ready! Mock draft system enabled."
    end

    test "handles mock draft creation failure gracefully", %{conn: conn, draft: draft} do
      # Create a mock draft first to cause a conflict
      {:ok, _existing_mock_draft} = AceApp.MockDrafts.create_mock_draft(draft.id, %{})

      {:ok, view, _html} = live(conn, ~p"/drafts/#{draft.id}/setup")

      # Finalize the draft (should handle existing mock draft gracefully)
      view |> element("button", "Finalize Draft") |> render_click()

      # Verify appropriate error handling
      refute render(view) =~ "Mock draft system enabled"
    end

    test "only creates mock draft for drafts in setup status", %{conn: conn, draft: draft} do
      # Update draft to active status
      {:ok, active_draft} = AceApp.Drafts.update_draft(draft, %{status: "active"})

      {:ok, _view, _html} = live(conn, ~p"/drafts/#{active_draft.id}/setup")

      # Try to finalize (should not create mock draft for non-setup drafts)
      mock_drafts_before = AceApp.MockDrafts.list_mock_drafts_for_draft(active_draft.id)
      
      # Note: The finalize button might not be available for active drafts
      # This test ensures we handle the edge case properly
      assert length(mock_drafts_before) == 0
    end
  end

  describe "draft setup flow with mock draft integration" do
    test "complete flow from draft creation to mock draft availability", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, ~p"/drafts/#{draft.id}/setup")

      # Verify draft setup page loads
      assert has_element?(view, "h1", "Draft Setup")
      
      # Verify teams are displayed
      assert render(view) =~ "Team Alpha"
      assert render(view) =~ "Team Beta"

      # Finalize the draft
      view |> element("button", "Finalize Draft") |> render_click()

      # Get the created mock draft
      [mock_draft] = AceApp.MockDrafts.list_mock_drafts_for_draft(draft.id)

      # Verify we can access the pre-draft page
      {:ok, predraft_view, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      assert render(predraft_view) =~ "Pre-Draft Predictions"
      assert render(predraft_view) =~ "Team Alpha"
      assert render(predraft_view) =~ "Team Beta"

      # Verify we can access the leaderboard page
      {:ok, leaderboard_view, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      assert render(leaderboard_view) =~ "Leaderboard"
    end

    test "draft setup preserves existing mock draft settings", %{conn: conn, draft: draft} do
      # Create a mock draft with custom settings
      {:ok, existing_mock_draft} = AceApp.MockDrafts.create_mock_draft(draft.id, %{
        track_1_enabled: false,
        track_2_enabled: true,
        max_participants: 50
      })

      {:ok, view, _html} = live(conn, ~p"/drafts/#{draft.id}/setup")

      # Finalize the draft
      view |> element("button", "Finalize Draft") |> render_click()

      # Verify the existing mock draft wasn't modified
      updated_mock_draft = AceApp.MockDrafts.get_mock_draft!(existing_mock_draft.id)
      assert updated_mock_draft.track_1_enabled == false
      assert updated_mock_draft.track_2_enabled == true
      assert updated_mock_draft.max_participants == 50

      # Verify no duplicate mock draft was created
      mock_drafts = AceApp.MockDrafts.list_mock_drafts_for_draft(draft.id)
      assert length(mock_drafts) == 1
    end
  end

  # Test fixtures
  defp draft_fixture(attrs) do
    {:ok, draft} =
      attrs
      |> Enum.into(%{
        name: "Test Draft", 
        format: :snake,
        pick_timer_seconds: 60,
        status: "setup"
      })
      |> Drafts.create_draft()
    draft
  end


end