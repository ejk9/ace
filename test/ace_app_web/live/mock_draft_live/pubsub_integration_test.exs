defmodule AceAppWeb.MockDraftLive.PubSubIntegrationTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import AceApp.DataCase

  alias AceApp.{Drafts, MockDrafts}

  describe "LivePredictionLive PubSub integration" do
    setup do
      # Create test data
      draft = draft_fixture(%{status: :active})
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Red Team", pick_order_position: 2})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      player3 = player_fixture(draft.id, %{display_name: "Keria", preferred_roles: [:support]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        teams: [team1, team2],
        players: [player1, player2, player3]
      }
    end

    test "multiple participants receive pick_made events simultaneously", %{conn: conn, mock_draft: mock_draft, draft: draft, teams: [team1, _], players: [player1, player2, _]} do
      # Start two separate LiveView sessions (simulating different users)
      {:ok, view1, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      {:ok, view2, _} = live(build_conn(), "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Both join as participants
      view1
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "Player1"}})
      |> render_submit()
      
      view2
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "Player2"}})
      |> render_submit()
      
      # Both make predictions for pick 1
      render_click(view1, "make_prediction", %{"player_id" => to_string(player1.id)})
      render_click(view2, "make_prediction", %{"player_id" => to_string(player2.id)})
      
      # Verify both have locked predictions
      assert render(view1) =~ "Your Prediction for Pick #1"
      assert render(view2) =~ "Your Prediction for Pick #1"
      
      # Create actual pick
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Simulate the pick_made event being broadcast
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick})
      
      # Give time for async message processing
      :timer.sleep(50)
      
      # Both views should receive the update
      html1 = render(view1)
      html2 = render(view2)
      
      assert html1 =~ "Pick #{pick.pick_number} made! Scores updated."
      assert html2 =~ "Pick #{pick.pick_number} made! Scores updated."
      
      # Player1 should have points (correct prediction), Player2 should have 0 (wrong prediction)
      # The UI should reflect updated scores
      participants = MockDrafts.list_participants_for_mock_draft(mock_draft.id)
      [participant1, participant2] = Enum.sort_by(participants, & &1.display_name)
      
      assert participant1.total_score == 10  # Correct prediction
      assert participant2.total_score == 0   # Wrong prediction
    end

    test "participant scores update in real-time across all views", %{conn: conn, mock_draft: mock_draft, draft: draft, teams: [team1, _], players: [player1, _, _]} do
      # Start multiple views
      {:ok, view1, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      {:ok, view2, _} = live(build_conn(), "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      {:ok, spectator_view, _} = live(build_conn(), "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # First two join as participants, third is spectator
      view1
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "ActivePlayer"}})
      |> render_submit()
      
      view2
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "OtherPlayer"}})
      |> render_submit()
      
      # ActivePlayer makes prediction
      render_click(view1, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # All views should show updated participant count
      assert render(view1) =~ "2 participants"
      assert render(view2) =~ "2 participants"
      assert render(spectator_view) =~ "2 participants"
      
      # Create matching pick to give ActivePlayer points
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick})
      
      :timer.sleep(50)
      
      # All views should show updated scores in participants list
      html1 = render(view1)
      html2 = render(view2)
      html_spectator = render(spectator_view)
      
      [html1, html2, html_spectator]
      |> Enum.each(fn html ->
        assert html =~ "ActivePlayer"
        assert html =~ "10"  # ActivePlayer's score should be visible
        assert html =~ "OtherPlayer"
      end)
    end

    test "new participants see updated state when joining mid-draft", %{conn: conn, mock_draft: mock_draft, draft: draft, teams: [team1, _], players: [player1, _, _]} do
      # Create some draft history first
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "EarlyPlayer")
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      MockDrafts.score_pick_predictions(pick)
      
      # New participant joins
      {:ok, new_view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should see existing participant and their score
      assert html =~ "EarlyPlayer"
      assert html =~ "10"  # EarlyPlayer's score
      assert html =~ "1 participants"
      
      # Should show next pick number (2)
      assert html =~ "Pick #2"
      
      # Join as new participant
      new_view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "LateJoiner"}})
      |> render_submit()
      
      # Should now show 2 participants
      html = render(new_view)
      assert html =~ "2 participants"
      assert html =~ "LateJoiner"
      assert html =~ "EarlyPlayer"
      
      # Should be able to predict next pick
      assert html =~ "Who will be picked next?"
    end

    test "handles multiple rapid pick_made events correctly", %{conn: conn, mock_draft: mock_draft, draft: draft, teams: [team1, team2], players: [player1, player2, player3]} do
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make predictions for multiple picks
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "SpeedPlayer"}})
      |> render_submit()
      
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      
      # Make predictions for picks 1, 2, 3
      {:ok, _} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      {:ok, _} = MockDrafts.create_live_prediction(participant.id, 2, player2.id)
      {:ok, _} = MockDrafts.create_live_prediction(participant.id, 3, player3.id)
      
      # Create picks rapidly
      {:ok, pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      {:ok, pick2} = Drafts.make_pick(draft.id, team2.id, player2.id, random_champion_id())
      {:ok, pick3} = Drafts.make_pick(draft.id, team1.id, player3.id, random_champion_id())
      
      # Broadcast events rapidly
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick1})
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick2})
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick3})
      
      # Allow time for all events to process
      :timer.sleep(100)
      
      # Final state should be correct
      updated_participant = MockDrafts.get_participant!(participant.id)
      assert updated_participant.total_score == 30  # 3 correct predictions × 10 points
      assert updated_participant.predictions_made == 3
      
      # UI should reflect final scores
      html = render(view)
      assert html =~ "30"  # Total score
    end

    test "handles PubSub events when participant not current user", %{conn: conn, mock_draft: mock_draft, draft: draft, teams: [team1, _], players: [player1, _, _]} do
      # Create participant outside the view (simulating another user's action)
      {:ok, other_participant} = MockDrafts.create_participant(mock_draft.id, "OtherUser")
      {:ok, _prediction} = MockDrafts.create_live_prediction(other_participant.id, 1, player1.id)
      
      # Start view as spectator (not joined)
      {:ok, spectator_view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should see the other participant
      assert render(spectator_view) =~ "OtherUser"
      assert render(spectator_view) =~ "1 participants"
      
      # Create pick that scores the other participant's prediction
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick})
      
      :timer.sleep(50)
      
      # Should see updated scores for the other participant
      html = render(spectator_view)
      assert html =~ "Pick #{pick.pick_number} made! Scores updated."
      assert html =~ "10"  # OtherUser's score
    end

    test "PubSub subscription is established on mount", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Mount the view
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Verify subscription exists by checking if we can broadcast to it
      # We'll send a test message and verify it doesn't crash the view
      result = Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:test_message, "hello"})
      assert result == :ok
      
      # Give time for message processing
      :timer.sleep(10)
      
      # View should still be alive (message handled gracefully)
      # Test that the view is still responsive by checking it can render
      html = render(view)
      assert html =~ "Live Predictions"
    end

    test "PubSub events are ignored for different drafts", %{conn: conn, mock_draft: mock_draft, teams: [_team1, _], players: [player1, _, _]} do
      # Create another draft
      other_draft = draft_fixture(%{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make prediction
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Broadcast pick_made event for DIFFERENT draft
      fake_pick = %{pick_number: 1, player_id: player1.id, draft_id: other_draft.id}
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{other_draft.id}", {:pick_made, fake_pick})
      
      :timer.sleep(50)
      
      # Should not affect our view
      html = render(view)
      refute html =~ "Pick 1 made! Scores updated."
      
      # Our participant should still have 0 score
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      assert participant.total_score == 0
    end

    test "view handles malformed PubSub events gracefully", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Send various malformed events
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, nil})
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, %{}})
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:unknown_event, "data"})
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", "invalid_format")
      
      :timer.sleep(50)
      
      # View should still be functional
      html = render(view)
      assert html =~ "Live Mock Draft Predictions"
      
      # Should be able to join normally
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      assert render(view) =~ "Participating as: Testplayer"
    end
  end

  describe "Real-time scoring integration" do
    setup do
      # Create active draft
      draft = draft_fixture(%{status: :active})
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        team1: team1,
        players: [player1, player2]
      }
    end

    test "scoring system integrates with PubSub for real-time updates", %{conn: conn, mock_draft: mock_draft, draft: draft, team1: team1, players: [player1, _player2]} do
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make predictions
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Verify prediction exists
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      prediction = MockDrafts.get_live_prediction(participant.id, 1)
      assert prediction.predicted_player_id == player1.id
      assert prediction.points_awarded == 0  # Not scored yet
      
      # Create pick - this triggers scoring via the normal draft flow
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # The actual draft system would broadcast this, but we'll simulate it
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick})
      
      :timer.sleep(50)
      
      # Prediction should now be scored
      updated_prediction = MockDrafts.get_live_prediction(participant.id, 1)
      assert updated_prediction.points_awarded == 10  # Exact match
      assert updated_prediction.prediction_type == "exact"
      assert updated_prediction.is_locked == true
      
      # Participant score should be updated
      updated_participant = MockDrafts.get_participant!(participant.id)
      assert updated_participant.total_score == 10
      assert updated_participant.predictions_made == 1
      
      # UI should reflect the updates
      html = render(view)
      assert html =~ "Score: 10"
      assert html =~ "Predictions: 1"
    end

    test "multiple predictions scored correctly in sequence", %{conn: conn, mock_draft: mock_draft, draft: draft, team1: team1, players: [player1, player2]} do
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "MultiPlayer"}})
      |> render_submit()
      
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      
      # Make multiple predictions
      {:ok, _} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      {:ok, _} = MockDrafts.create_live_prediction(participant.id, 2, player2.id)
      
      # Score pick 1 (correct)
      {:ok, pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick1})
      :timer.sleep(25)
      
      # Check interim state
      interim_participant = MockDrafts.get_participant!(participant.id)
      assert interim_participant.total_score == 10
      assert interim_participant.predictions_made == 1
      
      # Score pick 2 (also correct)
      {:ok, pick2} = Drafts.make_pick(draft.id, team1.id, player2.id, random_champion_id())
      Phoenix.PubSub.broadcast(AceApp.PubSub, "draft:#{draft.id}", {:pick_made, pick2})
      :timer.sleep(25)
      
      # Check final state
      final_participant = MockDrafts.get_participant!(participant.id)
      assert final_participant.total_score == 20
      assert final_participant.predictions_made == 2
      assert final_participant.accuracy_percentage == 100.0
      
      # UI should show cumulative updates
      html = render(view)
      assert html =~ "Score: 20"
      assert html =~ "Predictions: 2"
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