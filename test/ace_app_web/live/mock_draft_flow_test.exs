defmodule AceAppWeb.MockDraftFlowTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  
  alias AceApp.Drafts
  # alias AceApp.MockDrafts  # Currently unused

  setup do
    draft = draft_fixture(%{status: "setup"})
    
    {:ok, team1} = Drafts.create_team(draft.id, %{"name" => "Team Alpha"})
    {:ok, team2} = Drafts.create_team(draft.id, %{"name" => "Team Beta"})
    
    # Create 5 players for each team (standard LoL roster)
    players_team1 = for role <- ["top", "jungle", "mid", "adc", "support"] do
      {:ok, player} = Drafts.create_player(draft.id, %{
        "display_name" => "#{team1.name} #{String.capitalize(role)}",
        "preferred_roles" => [role]
      })
      player
    end

    players_team2 = for role <- ["top", "jungle", "mid", "adc", "support"] do
      {:ok, player} = Drafts.create_player(draft.id, %{
        "display_name" => "#{team2.name} #{String.capitalize(role)}",
        "preferred_roles" => [role]
      })
      player
    end

    %{
      draft: draft, 
      team1: team1, 
      team2: team2,
      players_team1: players_team1,
      players_team2: players_team2
    }
  end

  describe "complete mock draft flow" do
    test "end-to-end flow: draft setup -> mock draft creation -> participant registration -> predictions -> submission", 
         %{conn: conn, draft: draft, team1: _team1, team2: _team2, players_team1: players_team1} do
      
      # Step 1: Draft Setup and Finalization
      {:ok, setup_view, _html} = live(conn, ~p"/drafts/#{draft.id}/setup")
      
      assert has_element?(setup_view, "button", "Finalize Draft")
      setup_view |> element("button", "Finalize Draft") |> render_click()
      
      # Verify mock draft was created
      [mock_draft] = AceApp.MockDrafts.list_mock_drafts_for_draft(draft.id)
      assert mock_draft.draft_id == draft.id

      # Step 2: Access Pre-Draft Page
      {:ok, predraft_view, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      assert render(predraft_view) =~ "Pre-Draft Predictions"
      assert render(predraft_view) =~ "Join as Participant"

      # Step 3: Register as Participant
      predraft_view 
      |> form("#participant-form", participant: %{name: "TestUser123"})
      |> render_submit()

      assert render(predraft_view) =~ "TestUser123"
      assert render(predraft_view) =~ "Draft Builder"

      # Step 4: Make Predictions
      [player1, player2 | _] = players_team1

      # Predict pick 1 (Team 1, Pick 1)
      predraft_view
      |> element("[data-player-id='#{player1.id}']")
      |> render_click()
      
      predraft_view
      |> element("[data-team='1'][data-pick='1']")
      |> render_click()

      # Predict pick 2 (Team 2, Pick 1) 
      predraft_view
      |> element("[data-player-id='#{player2.id}']")
      |> render_click()
      
      predraft_view
      |> element("[data-team='2'][data-pick='1']")
      |> render_click()

      # Verify predictions are reflected in UI
      html = render(predraft_view)
      assert html =~ player1.name
      assert html =~ player2.name

      # Step 5: Complete Draft Submission
      # First, make predictions for all 10 picks to enable submission
      remaining_players = players_team1 ++ [hd(tl(tl(players_team1)))]
      
      for {player, pick_num} <- Enum.with_index(remaining_players, 3) do
        if pick_num <= 10 do
          team = if rem(pick_num, 2) == 1, do: "1", else: "2"
          team_pick = div(pick_num - 1, 2) + 1
          
          predraft_view
          |> element("[data-player-id='#{player.id}']")
          |> render_click()
          
          predraft_view
          |> element("[data-team='#{team}'][data-pick='#{team_pick}']")
          |> render_click()
        end
      end

      # Submit the complete draft
      predraft_view |> element("button", "Submit Complete Draft") |> render_click()

      # Verify submission success
      assert render(predraft_view) =~ "Draft submitted successfully"

      # Step 6: Verify Submission in Database
      submissions = AceApp.MockDrafts.list_submissions_for_mock_draft(mock_draft.id)
      assert length(submissions) == 1
      
      submission = hd(submissions)
      assert submission.participant_name == "TestUser123"
      assert submission.status == "submitted"

      # Verify predicted picks were created
      predicted_picks = AceApp.MockDrafts.list_predicted_picks_for_submission(submission.id)
      assert length(predicted_picks) >= 2  # At least the two we explicitly made

      # Step 7: Access Leaderboard
      {:ok, leaderboard_view, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
      
      assert render(leaderboard_view) =~ "Leaderboard"
      assert render(leaderboard_view) =~ "TestUser123"
    end

    test "multiple participants flow with different predictions", 
         %{conn: conn, draft: draft, players_team1: players_team1} do
      
      # Setup: Create mock draft
      {:ok, mock_draft} = AceApp.MockDrafts.create_mock_draft(draft.id, %{})

      # Participant 1
      {:ok, view1, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      view1 
      |> form("#participant-form", participant: %{name: "Player1"})
      |> render_submit()

      [player1 | _] = players_team1
      
      # Make a prediction
      view1
      |> element("[data-player-id='#{player1.id}']")
      |> render_click()
      
      view1
      |> element("[data-team='1'][data-pick='1']")
      |> render_click()

      # Participant 2 (new connection)
      {:ok, view2, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      
      view2 
      |> form("#participant-form", participant: %{name: "Player2"})
      |> render_submit()

      # Verify both participants are shown
      html1 = render(view1)
      html2 = render(view2)
      
      assert html1 =~ "Player1"
      assert html1 =~ "Player2"
      assert html2 =~ "Player1" 
      assert html2 =~ "Player2"

      # Verify participants list in database
      participants = AceApp.MockDrafts.list_participants_for_mock_draft(mock_draft.id)
      participant_names = Enum.map(participants, & &1.name)
      assert "Player1" in participant_names
      assert "Player2" in participant_names
    end

    test "error handling and validation in prediction flow", 
         %{conn: conn, draft: draft} do
      
      # Setup: Create mock draft
      {:ok, mock_draft} = AceApp.MockDrafts.create_mock_draft(draft.id, %{})

      {:ok, view, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")

      # Test: Try to submit without joining as participant
      assert render(view) =~ "Join as Participant"
      refute has_element?(view, "button", "Submit Complete Draft")

      # Test: Join with invalid name
      view 
      |> form("#participant-form", participant: %{name: ""})
      |> render_submit()

      assert render(view) =~ "can't be blank"

      # Test: Join with valid name
      view 
      |> form("#participant-form", participant: %{name: "ValidUser"})
      |> render_submit()

      assert render(view) =~ "ValidUser"

      # Test: Try to submit incomplete draft
      assert has_element?(view, "button[disabled]", "Submit Complete Draft")
      
      # The submit button should be disabled until all picks are made
      refute view |> element("button", "Submit Complete Draft") |> render_click() =~ "submitted successfully"
    end

    test "mock draft token validation and security", %{conn: conn} do
      # Test: Invalid token
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/mock-drafts/invalid-token-123/predraft")
      end

      # Test: Valid token format but non-existent
      fake_token = String.duplicate("a", 32)
      
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/mock-drafts/#{fake_token}/predraft")
      end
    end

    test "concurrent predictions and real-time updates", 
         %{conn: conn, draft: draft, players_team1: players_team1} do
      
      # Setup: Create mock draft  
      {:ok, mock_draft} = AceApp.MockDrafts.create_mock_draft(draft.id, %{})

      # Create two concurrent sessions
      {:ok, view1, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      {:ok, view2, _html} = live(conn, ~p"/mock-drafts/#{mock_draft.mock_draft_token}/predraft")

      # Both join as participants
      view1 
      |> form("#participant-form", participant: %{name: "User1"})
      |> render_submit()

      view2 
      |> form("#participant-form", participant: %{name: "User2"})
      |> render_submit()

      # Verify both see each other's participation
      assert render(view1) =~ "User2"
      assert render(view2) =~ "User1"

      # Test concurrent predictions don't interfere
      [player1, player2 | _] = players_team1

      # User1 makes prediction
      view1
      |> element("[data-player-id='#{player1.id}']")
      |> render_click()
      
      view1
      |> element("[data-team='1'][data-pick='1']")
      |> render_click()

      # User2 makes different prediction
      view2
      |> element("[data-player-id='#{player2.id}']")
      |> render_click()
      
      view2
      |> element("[data-team='1'][data-pick='1']")
      |> render_click()

      # Verify predictions are separate
      assert render(view1) =~ player1.name
      assert render(view2) =~ player2.name
      
      # Each user should see their own prediction, not the other's
      refute render(view1) =~ player2.name
      refute render(view2) =~ player1.name
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