defmodule AceAppWeb.MockDraftLive.LeaderboardTrackFilteringTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  # import AceApp.DataCase  # Currently unused

  alias AceApp.{Drafts, MockDrafts, Repo}

  describe "LeaderboardLive track filtering" do
    setup do
      # Create a completed draft with teams and players
      draft = draft_fixture(%{status: :completed})
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Red Team", pick_order_position: 2})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      
      # Create mock draft with both tracks enabled
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        predraft_enabled: true,
        live_predictions_enabled: true,
        submission_deadline: DateTime.add(DateTime.utc_now(), 86400, :second)
      })
      
      # Create Track 1 data (submissions)
      {:ok, submission1} = MockDrafts.create_submission(mock_draft.id, "PreDraftPlayer1")
      {:ok, submission2} = MockDrafts.create_submission(mock_draft.id, "PreDraftPlayer2")
      
      # Mark submissions as submitted with scores
      submission1
      |> Ecto.Changeset.change(%{
        is_submitted: true,
        total_accuracy_score: 85.5,
        exact_predictions: 3,
        partial_predictions: 2
      })
      |> Repo.update!()
      
      submission2
      |> Ecto.Changeset.change(%{
        is_submitted: true,
        total_accuracy_score: 72.0,
        exact_predictions: 2,
        partial_predictions: 3
      })
      |> Repo.update!()
      
      # Create Track 2 data (live participants)
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "LivePlayer1")
      {:ok, participant2} = MockDrafts.create_participant(mock_draft.id, "LivePlayer2")
      
      # Update participant scores
      participant1
      |> Ecto.Changeset.change(%{
        total_score: 25,
        predictions_made: 3,
        accuracy_percentage: 66.67
      })
      |> Repo.update!()
      
      participant2
      |> Ecto.Changeset.change(%{
        total_score: 30,
        predictions_made: 4,
        accuracy_percentage: 75.0
      })
      |> Repo.update!()
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        teams: [team1, team2],
        players: [player1, player2],
        submissions: [submission1, submission2],
        participants: [participant1, participant2]
      }
    end

    test "mount shows Track 1 by default", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Should default to Track 1
      assert view.assigns.active_track == "track1"
      
      # Should show Track 1 content
      assert html =~ "Pre-Draft Predictions Leaderboard"
      assert html =~ "PreDraftPlayer1"
      assert html =~ "PreDraftPlayer2"
      assert html =~ "85.5"  # submission1 score
      assert html =~ "72.0"  # submission2 score
      
      # Should not show Track 2 content
      refute html =~ "Live Predictions Leaderboard"
      refute html =~ "LivePlayer1"
      refute html =~ "LivePlayer2"
    end

    test "shows track selector for completed drafts", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Should show track selector buttons
      assert has_element?(view, "button[phx-click='switch_track'][phx-value-track='track1']", "Pre-Draft Predictions")
      assert has_element?(view, "button[phx-click='switch_track'][phx-value-track='track2']", "Live Predictions")
      
      # Track 1 should be active by default
      assert has_element?(view, "button.bg-blue-600.text-white", "Pre-Draft Predictions")
      assert has_element?(view, "button.text-slate-600", "Live Predictions")
    end

    test "switch_track event changes to Track 2", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Switch to Track 2
      render_click(view, "switch_track", %{"track" => "track2"})
      
      html = render(view)
      
      # Should now show Track 2 content
      assert view.assigns.active_track == "track2"
      assert html =~ "Live Predictions Leaderboard"
      assert html =~ "LivePlayer1"
      assert html =~ "LivePlayer2"
      assert html =~ "25"   # participant1 score
      assert html =~ "30"   # participant2 score
      
      # Should not show Track 1 content
      refute html =~ "Pre-Draft Predictions Leaderboard"
      refute html =~ "PreDraftPlayer1"
      refute html =~ "PreDraftPlayer2"
      
      # Track 2 button should now be active
      assert has_element?(view, "button.bg-green-600.text-white", "Live Predictions")
      assert has_element?(view, "button.text-slate-600", "Pre-Draft Predictions")
    end

    test "switch_track event can switch back to Track 1", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Switch to Track 2 then back to Track 1
      render_click(view, "switch_track", %{"track" => "track2"})
      render_click(view, "switch_track", %{"track" => "track1"})
      
      html = render(view)
      
      # Should be back to Track 1
      assert view.assigns.active_track == "track1"
      assert html =~ "Pre-Draft Predictions Leaderboard"
      assert html =~ "PreDraftPlayer1"
      refute html =~ "Live Predictions Leaderboard"
    end

    test "displays correct Track 1 leaderboard data", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Should show submissions in order of accuracy score (highest first)
      submission_rows = view |> element("tbody") |> render()
      
      # PreDraftPlayer1 (85.5) should appear before PreDraftPlayer2 (72.0)
      # Check order by finding positions in the string
      player1_pos = :binary.match(submission_rows, "PreDraftPlayer1") |> elem(0)
      player2_pos = :binary.match(submission_rows, "PreDraftPlayer2") |> elem(0)
      assert player1_pos < player2_pos
      
      # Should show accuracy scores
      assert html =~ "85.5%"
      assert html =~ "72.0%"
      
      # Should show prediction counts
      assert html =~ "3 exact"  # submission1
      assert html =~ "2 exact"  # submission2
      assert html =~ "2 partial"  # submission1
      assert html =~ "3 partial"  # submission2
    end

    test "displays correct Track 2 leaderboard data", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Switch to Track 2
      render_click(view, "switch_track", %{"track" => "track2"})
      html = render(view)
      
      # Should show participants in order of total score (highest first)
      participant_rows = view |> element("tbody") |> render()
      
      # LivePlayer2 (30 points) should appear before LivePlayer1 (25 points)
      player1_pos = :binary.match(participant_rows, "LivePlayer1") |> elem(0)
      player2_pos = :binary.match(participant_rows, "LivePlayer2") |> elem(0)
      assert player2_pos < player1_pos
      
      # Should show total scores
      assert html =~ "30"  # participant2 score
      assert html =~ "25"  # participant1 score
      
      # Should show prediction counts
      assert html =~ "3 predictions"  # participant1
      assert html =~ "4 predictions"  # participant2
      
      # Should show accuracy percentages
      assert html =~ "66.67%"  # participant1
      assert html =~ "75.0%"   # participant2
    end

    test "shows empty state for Track 1 when no submissions", %{conn: conn, draft: draft} do
      # Create mock draft without submissions
      {:ok, empty_mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        predraft_enabled: true
      })
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{empty_mock_draft.mock_draft_token}/leaderboard")
      
      assert html =~ "No submissions yet"
      assert html =~ "Be the first to submit predictions"
      assert has_element?(view, "svg.h-12.w-12.text-slate-400")
    end

    test "shows empty state for Track 2 when no participants", %{conn: conn, draft: draft} do
      # Create mock draft without participants
      {:ok, empty_mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{empty_mock_draft.mock_draft_token}/leaderboard")
      
      # Switch to Track 2
      render_click(view, "switch_track", %{"track" => "track2"})
      html = render(view)
      
      assert html =~ "No live participants yet"
      assert html =~ "Join the live predictions"
      assert has_element?(view, "svg.h-12.w-12.text-slate-400")
    end

    test "track selector not shown for incomplete drafts", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Update draft to active (not completed)
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Should not show track selector
      refute has_element?(view, "button[phx-click='switch_track']")
      
      # Should show status message instead
      assert html =~ "Draft Status: Active"
      assert html =~ "Leaderboard will be available once the draft is completed"
    end

    test "handles invalid track selection gracefully", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Try to switch to invalid track
      render_click(view, "switch_track", %{"track" => "invalid_track"})
      
      # Should remain on current track (track1)
      assert view.assigns.active_track == "track1"
      assert render(view) =~ "Pre-Draft Predictions Leaderboard"
    end

    test "participant links work in Track 1", %{conn: conn, mock_draft: mock_draft, submissions: [submission1, _]} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Should have clickable participant names linking to their predictions
      assert has_element?(view, "a[href*='#{submission1.submission_token}']", "PreDraftPlayer1")
      
      # Link should point to correct predraft view
      expected_path = "/mock-drafts/#{mock_draft.mock_draft_token}/predraft/#{submission1.submission_token}"
      assert html =~ expected_path
    end

    test "participant links work in Track 2", %{conn: conn, mock_draft: mock_draft, participants: [participant1, _]} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Switch to Track 2
      render_click(view, "switch_track", %{"track" => "track2"})
      html = render(view)
      
      # Should have clickable participant names linking to their view
      assert has_element?(view, "a[href*='#{participant1.participant_token}']", "LivePlayer1")
      
      # Link should point to correct participant view
      expected_path = "/mock-drafts/#{mock_draft.mock_draft_token}/participant/#{participant1.participant_token}"
      assert html =~ expected_path
    end

    test "displays different styling for each track", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      # Track 1 should have blue styling
      assert html =~ "from-blue-50 to-indigo-50"
      assert html =~ "text-blue-900"
      
      # Switch to Track 2
      render_click(view, "switch_track", %{"track" => "track2"})
      html = render(view)
      
      # Track 2 should have green styling
      assert html =~ "from-green-50 to-emerald-50"
      assert html =~ "text-green-900"
    end
  end

  # Helper functions for creating test data
  defp draft_fixture(attrs) do
    {:ok, draft} = 
      attrs
      |> Enum.into(%{
        name: "Test Draft #{System.unique_integer()}",
        format: :snake,
        pick_timer_seconds: 60,
        organizer_token: generate_token(),
        spectator_token: generate_token(),
        status: :setup
      })
      |> Drafts.create_draft()

    draft
  end

  defp team_fixture(draft_id, attrs) do
    {:ok, team} = 
      attrs
      |> Enum.into(%{
        name: "Test Team #{System.unique_integer()}",
        pick_order_position: 1,
        captain_token: generate_token(),
        team_member_token: generate_token()
      })
      |> then(&Drafts.create_team(draft_id, &1))

    team
  end

  defp player_fixture(draft_id, attrs) do
    {:ok, player} = 
      attrs
      |> Enum.into(%{
        display_name: "Test Player #{System.unique_integer()}",
        preferred_roles: [:mid, :adc]
      })
      |> then(&Drafts.create_player(draft_id, &1))

    player
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end