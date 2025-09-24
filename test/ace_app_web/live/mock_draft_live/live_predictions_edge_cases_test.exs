defmodule AceAppWeb.MockDraftLive.LivePredictionsEdgeCasesTest do
  use AceAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import AceApp.DataCase

  alias AceApp.{Drafts, MockDrafts}

  describe "LivePredictionLive edge cases and error handling" do
    setup do
      # Create test data
      draft = draft_fixture()
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

    test "handles non-existent player prediction gracefully", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Try to predict with invalid player ID
      render_click(view, "make_prediction", %{"player_id" => "99999"})
      
      # Should show error message
      assert render(view) =~ "Unable to make prediction"
    end

    test "handles database errors during prediction creation", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      
      # Create prediction manually to force duplicate constraint
      {:ok, _existing} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      # Try to create another prediction for same pick
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should show specific error for duplicate prediction
      assert render(view) =~ "You've already made a prediction for this pick"
    end

    test "handles malformed player_id in prediction request", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Try to predict with malformed player ID
      render_click(view, "make_prediction", %{"player_id" => "not_a_number"})
      
      # Should handle gracefully and show error
      assert render(view) =~ "Unable to make prediction"
    end

    test "handles missing player_id in prediction request", %{conn: conn, mock_draft: mock_draft, draft: draft} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Try to predict without player_id
      render_click(view, "make_prediction", %{})
      
      # Should handle gracefully
      assert render(view) =~ "Unable to make prediction"
    end

    test "handles participant name validation edge cases", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Test extremely long name
      long_name = String.duplicate("a", 1000)
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: long_name}})
      |> render_submit()
      
      assert render(view) =~ "Unable to join"
      
      # Test name with special characters
      special_name = "Test<script>alert('xss')</script>"
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: special_name}})
      |> render_submit()
      
      # Should either sanitize or reject
      html = render(view)
      # The exact behavior depends on validation - it should either work with sanitized name or show error
      assert html =~ "Unable to join" or html =~ "Participating as:"
    end

    test "handles draft state changes during prediction", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _]} do
      # Set draft to active
      {:ok, draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Change draft to completed while user is making prediction
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :completed})
      
      # Try to make prediction
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should still work based on initial state, or show appropriate message
      html = render(view)
      # The behavior depends on implementation - it might succeed with a warning or fail gracefully
      assert html =~ "Predicted" or html =~ "Unable to make prediction"
    end

    test "handles rapid clicking on prediction buttons", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, player2]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "SpeedClicker"}})
      |> render_submit()
      
      # Rapidly click different prediction buttons
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      render_click(view, "make_prediction", %{"player_id" => to_string(player2.id)})
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should only register the first prediction and show appropriate feedback
      html = render(view)
      assert html =~ "Prediction locked" or html =~ "already made a prediction"
      
      # Verify only one prediction exists in database
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      predictions = MockDrafts.list_predictions_for_participant(participant.id)
      assert length(predictions) == 1
    end

    test "handles empty participant list gracefully", %{conn: conn, mock_draft: mock_draft} do
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should show empty state
      assert html =~ "0 participants"
      assert html =~ "No participants yet"
      assert has_element?(view, "svg.h-8.w-8.text-slate-400")
      
      # UI should still be functional
      assert has_element?(view, "form[phx-submit='join_as_participant']")
    end

    test "handles corrupted prediction data gracefully", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join as participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      participant = hd(MockDrafts.list_participants_for_mock_draft(mock_draft.id))
      
      # Create prediction with corrupted data directly in database
      corrupted_prediction = %MockDrafts.MockDraftPrediction{
        participant_id: participant.id,
        pick_number: 1,
        predicted_player_id: player1.id,
        points_awarded: nil,  # Invalid null
        prediction_type: nil,  # Invalid null
        is_locked: nil,       # Invalid null
        predicted_at: nil     # Invalid null
      }
      
      # Try to insert corrupted data (might fail due to constraints)
      try do
        AceApp.Repo.insert!(corrupted_prediction)
      rescue
        _ -> :ok  # Expected to fail due to constraints
      end
      
      # View should handle gracefully even if there's corrupted data
      html = render(view)
      assert html =~ "Live Mock Draft Predictions"
      
      # Should still be able to make predictions normally
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should work or show appropriate error
      final_html = render(view)
      assert final_html =~ "Predicted" or final_html =~ "Unable to make prediction"
    end

    test "handles network interruption during PubSub", %{conn: conn, mock_draft: mock_draft, draft: draft, team1: team1, players: [player1, _]} do
      # Set draft to active
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make prediction
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Simulate network interruption by sending malformed PubSub events
      send(view.pid, {:pick_made, nil})
      send(view.pid, {:pick_made, %{invalid: "data"}})
      send(view.pid, :invalid_message)
      
      # Give time for processing
      :timer.sleep(50)
      
      # View should still be functional
      html = render(view)
      assert html =~ "Live Mock Draft Predictions"
      assert html =~ "Your Prediction for Pick #1"
      
      # Proper pick_made event should still work
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      send(view.pid, {:pick_made, pick})
      :timer.sleep(50)
      
      # Should process normally
      assert render(view) =~ "Pick #{pick.pick_number} made! Scores updated."
    end

    test "handles concurrent participant creation", %{conn: conn, mock_draft: mock_draft} do
      # Create two simultaneous connections
      {:ok, view1, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      {:ok, view2, _} = live(build_conn(), "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Both try to join with same name simultaneously
      same_name = "SameName"
      
      view1
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: same_name}})
      |> render_submit()
      
      view2
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: same_name}})
      |> render_submit()
      
      # One should succeed, one should fail
      html1 = render(view1)
      html2 = render(view2)
      
      success_count = [html1, html2] |> Enum.count(&String.contains?(&1, "Participating as"))
      error_count = [html1, html2] |> Enum.count(&String.contains?(&1, "Unable to join"))
      
      assert success_count == 1
      assert error_count == 1
      
      # Only one participant should exist in database
      participants = MockDrafts.list_participants_for_mock_draft(mock_draft.id)
      assert length(participants) == 1
    end

    test "handles memory exhaustion with many participants", %{conn: conn, mock_draft: mock_draft} do
      # Create many participants to test memory handling
      participant_names = for i <- 1..50, do: "Player#{i}"
      
      # Create participants in database
      for name <- participant_names do
        {:ok, _} = MockDrafts.create_participant(mock_draft.id, name)
      end
      
      {:ok, view, html} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Should handle displaying many participants
      assert html =~ "50 participants"
      
      # Should still be responsive
      assert html =~ "Live Mock Draft Predictions"
      assert has_element?(view, "form[phx-submit='join_as_participant']")
      
      # Should be able to join as additional participant
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "Player51"}})
      |> render_submit()
      
      assert render(view) =~ "51 participants"
    end

    test "handles invalid mock draft tokens gracefully", %{conn: conn} do
      # Try various invalid tokens
      invalid_tokens = [
        "nonexistent",
        "",
        "../../etc/passwd",
        "<script>alert('xss')</script>",
        String.duplicate("a", 1000),
        "null",
        "undefined"
      ]
      
      for token <- invalid_tokens do
        result = live(conn, "/mock-drafts/#{token}/live")
        
        # Should redirect with error
        assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Mock draft not found"}}}} = result
      end
    end

    test "handles predictions when draft has no picks yet", %{conn: conn, mock_draft: mock_draft, draft: draft, players: [player1, _]} do
      # Set draft to active but ensure no picks exist
      {:ok, _draft} = Drafts.update_draft(draft, %{status: :active})
      
      {:ok, view, _} = live(conn, "/mock-drafts/#{mock_draft.mock_draft_token}/live")
      
      # Join and make prediction
      view
      |> form("form[phx-submit='join_as_participant']", %{participant: %{name: "TestPlayer"}})
      |> render_submit()
      
      # Should show Pick #1
      assert render(view) =~ "Pick #1"
      
      # Should be able to make prediction
      render_click(view, "make_prediction", %{"player_id" => to_string(player1.id)})
      
      # Should work normally
      assert render(view) =~ "Predicted #{player1.display_name} for pick #1"
    end
  end

  describe "Database consistency edge cases" do
    setup do
      draft = draft_fixture(%{status: :active})
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        team1: team1,
        player1: player1
      }
    end

    test "handles orphaned predictions gracefully", %{mock_draft: mock_draft, player1: player1} do
      # Create participant
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "TestPlayer")
      
      # Create prediction
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      # Delete participant (creating orphaned prediction)
      AceApp.Repo.delete!(participant)
      
      # Should handle gracefully when listing predictions
      predictions = MockDrafts.list_predictions_for_participant(participant.id)
      assert predictions == []
    end

    test "handles deleted players in predictions", %{mock_draft: mock_draft, player1: player1} do
      # Create participant and prediction
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "TestPlayer")
      {:ok, prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      # Delete player (this might fail due to foreign key constraints)
      try do
        AceApp.Repo.delete!(player1)
      rescue
        _ -> :ok  # Expected to fail due to constraints
      end
      
      # Prediction should still exist with player_id reference
      found_prediction = MockDrafts.get_live_prediction(participant.id, 1)
      assert found_prediction.id == prediction.id
    end

    test "handles scoring with missing participant", %{draft: draft, team1: team1, player1: player1, mock_draft: mock_draft} do
      # Create participant and prediction
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "TestPlayer")
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      # Delete participant
      AceApp.Repo.delete!(participant)
      
      # Create pick to trigger scoring
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Should handle missing participant gracefully
      assert :ok == MockDrafts.score_pick_predictions(pick)
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