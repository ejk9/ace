defmodule AceAppWeb.MockDraftLive.PreDraftLiveTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  # import AceApp.DataCase  # Currently unused

  alias AceApp.{Drafts, MockDrafts}

  describe "PreDraftLive" do
    setup do
      # Create a draft with teams and players
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Red Team", pick_order_position: 2})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      
      # Create mock draft
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        predraft_enabled: true,
        submission_deadline: DateTime.add(DateTime.utc_now(), 86400, :second)
      })
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        teams: [team1, team2],
        players: [player1, player2]
      }
    end

    test "mount with valid token loads mock draft and draft data", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      assert html =~ "Mock Draft Prediction"
      assert html =~ mock_draft.draft.name
      assert html =~ "Join Mock Draft"
      assert has_element?(view, "form[phx-submit='join_predraft']")
    end

    test "mount with invalid token redirects with error", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Mock draft not found"}}}} =
        live(conn, "/mock-drafts/invalid_token/predraft")
    end

    test "mount with predraft disabled redirects with error", %{conn: conn, draft: draft} do
      {:ok, disabled_mock_draft} = MockDrafts.create_mock_draft(draft.id, %{predraft_enabled: false})
      
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Pre-draft submissions are not enabled for this mock draft"}}}} =
        live(conn, "/mock-drafts/#{disabled_mock_draft.mock_draft_token}/predraft")
    end

    test "shows deadline passed message when deadline has passed", %{conn: conn, draft: draft} do
      {:ok, expired_mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        submission_deadline: DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
      })
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{expired_mock_draft.mock_draft_token}/predraft")
      
      assert html =~ "Submission Deadline Passed"
      assert has_element?(view, "button[disabled]", "Deadline Passed")
    end

    test "join_predraft event creates submission and shows draft builder", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      participant_name = "TestPlayer"
      
      # Submit join form
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: participant_name})
      |> render_submit()
      
      # Should now show draft builder interface
      assert has_element?(view, "h2", "Building Draft for #{participant_name}")
      assert has_element?(view, ".draft-board")
      assert has_element?(view, ".player-pool")
      assert has_element?(view, "button[phx-click='submit_complete_draft']")
      
      # Verify submission was created in database
      submission = MockDrafts.get_submission_by_token(view.assigns.submission.submission_token)
      assert submission.participant_name == participant_name
      assert submission.mock_draft_id == mock_draft.id
    end

    test "join_predraft prevents empty participant name", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Submit form with empty name
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "   "})
      |> render_submit()
      
      # Should show error and stay on join form
      assert render(view) =~ "Please enter your name"
      assert has_element?(view, "form[phx-submit='join_predraft']")
    end

    test "join_predraft prevents duplicate participant names", %{conn: conn, mock_draft: mock_draft} do
      participant_name = "TestPlayer"
      
      # Create existing submission
      {:ok, _existing_submission} = MockDrafts.create_submission(mock_draft.id, participant_name)
      
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Try to join with same name
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: participant_name})
      |> render_submit()
      
      # Should show error
      assert render(view) =~ "That name is already taken"
      assert has_element?(view, "form[phx-submit='join_predraft']")
    end

    test "update_prediction event saves predicted pick", %{conn: conn, mock_draft: mock_draft, teams: [team1, _team2], players: [player1, _player2]} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join first
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      # Update a prediction
      pick_number = 1
      view
      |> element("form")
      |> render_change(%{
        "pick_number" => to_string(pick_number),
        "team_id" => to_string(team1.id),
        "player_id" => to_string(player1.id)
      })
      
      # Send update_prediction event
      render_hook(view, "update_prediction", %{
        "pick_number" => to_string(pick_number),
        "team_id" => to_string(team1.id),
        "player_id" => to_string(player1.id)
      })
      
      # Check that prediction was saved
      assert render(view) =~ "Prediction updated for pick ##{pick_number}"
      
      # Verify in assigns
      assert Map.has_key?(view.assigns.predicted_picks, pick_number)
      predicted_pick = Map.get(view.assigns.predicted_picks, pick_number)
      assert predicted_pick.team_id == team1.id
      assert predicted_pick.player_id == player1.id
    end

    test "remove_prediction event removes predicted pick", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join and add a prediction first
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      pick_number = 1
      # Add prediction to local state
      send(view.pid, {:update_predicted_picks, %{pick_number => %{team_id: 1, player_id: 1}}})
      
      # Remove prediction
      render_hook(view, "remove_prediction", %{"pick_number" => to_string(pick_number)})
      
      # Check that prediction was removed
      assert render(view) =~ "Prediction removed for pick ##{pick_number}"
      refute Map.has_key?(view.assigns.predicted_picks, pick_number)
    end

    test "submit_complete_draft requires all picks to be completed", %{conn: conn, mock_draft: mock_draft, teams: teams} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join first
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      # Try to submit without completing all picks
      render_hook(view, "submit_complete_draft", %{})
      
      total_picks_needed = length(teams) * 5
      assert render(view) =~ "Please complete all #{total_picks_needed} picks before submitting"
    end

    test "submit_complete_draft succeeds when all picks are completed", %{conn: conn, mock_draft: mock_draft, teams: teams, players: [player1, player2]} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join first
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      # Complete all required picks (2 teams * 5 picks = 10 picks)
      total_picks = length(teams) * 5
      predicted_picks = for pick_number <- 1..total_picks, into: %{} do
        player = if rem(pick_number, 2) == 0, do: player1, else: player2
        {pick_number, %{team_id: hd(teams).id, player_id: player.id}}
      end
      
      # Update the view's state with completed picks
      send(view.pid, {:update_predicted_picks, predicted_picks})
      
      # Submit complete draft
      render_hook(view, "submit_complete_draft", %{})
      
      # Should show success message
      assert render(view) =~ "Draft submitted successfully!"
      assert has_element?(view, "a", "View Leaderboard")
      
      # Verify submission was marked as submitted
      submission = MockDrafts.get_submission_by_token(view.assigns.submission.submission_token)
      assert submission.is_submitted == true
    end

    test "displays team roster slots with correct pick numbers", %{conn: conn, mock_draft: mock_draft, teams: [team1, team2]} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join to see draft builder
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      html = render(view)
      
      # Should show team names
      assert html =~ team1.name
      assert html =~ team2.name
      
      # Should show pick slots for each team
      # In snake draft with 2 teams: Team 1 gets picks 1,4,5,8,9 and Team 2 gets picks 2,3,6,7,10
      assert html =~ "#1"  # Team 1, Round 1
      assert html =~ "#2"  # Team 2, Round 1
      assert html =~ "#3"  # Team 2, Round 2
      assert html =~ "#4"  # Team 1, Round 2
    end

    test "displays available players with role information", %{conn: conn, mock_draft: mock_draft, players: [player1, player2]} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join to see draft builder
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      html = render(view)
      
      # Should show player names
      assert html =~ player1.display_name
      assert html =~ player2.display_name
      
      # Should show player roles
      assert html =~ "mid"  # player1's role
      assert html =~ "jungle"  # player2's role
    end

    test "shows submission progress indicator", %{conn: conn, mock_draft: mock_draft, teams: teams} do
      {:ok, view, _html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      # Join to see draft builder
      view
      |> form("form[phx-submit='join_predraft']", %{participant_name: "TestPlayer"})
      |> render_submit()
      
      html = render(view)
      total_picks = length(teams) * 5
      
      # Should show progress indicator
      assert html =~ "0/#{total_picks}"
      assert html =~ "Picks Complete"
      
      # Should show progress bar
      assert has_element?(view, ".bg-blue-500")  # Progress bar fill
    end
  end

  # Helper functions for creating test data
  defp draft_fixture(attrs \\ %{}) do
    {:ok, draft} = 
      attrs
      |> Enum.into(%{
        name: "Test Draft #{System.unique_integer()}",
        format: :snake,
        pick_timer_seconds: 60,
        organizer_token: generate_token(),
        spectator_token: generate_token()
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