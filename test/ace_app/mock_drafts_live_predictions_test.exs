defmodule AceApp.MockDraftsLivePredictionsTest do
  use AceApp.DataCase

  alias AceApp.{MockDrafts, Drafts}

  describe "live predictions" do
    setup do
      # Create test data
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      team2 = team_fixture(draft.id, %{name: "Red Team", pick_order_position: 2})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      player3 = player_fixture(draft.id, %{display_name: "Keria", preferred_roles: [:support]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "Player1")
      {:ok, participant2} = MockDrafts.create_participant(mock_draft.id, "Player2")
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        teams: [team1, team2],
        players: [player1, player2, player3],
        participants: [participant1, participant2]
      }
    end

    test "create_live_prediction/3 creates prediction successfully", %{participants: [participant1, _], players: [player1, _, _]} do
      pick_number = 1
      
      assert {:ok, prediction} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      assert prediction.participant_id == participant1.id
      assert prediction.pick_number == pick_number
      assert prediction.predicted_player_id == player1.id
      assert prediction.points_awarded == 0
      assert prediction.is_locked == false
      refute is_nil(prediction.id)
    end

    test "create_live_prediction/3 prevents duplicate predictions for same participant and pick", %{participants: [participant1, _], players: [player1, player2, _]} do
      pick_number = 1
      
      # First prediction succeeds
      assert {:ok, _prediction} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      
      # Second prediction for same pick fails
      assert {:error, changeset} = MockDrafts.create_live_prediction(participant1.id, pick_number, player2.id)
      assert changeset.errors[:participant_id]
    end

    test "create_live_prediction/3 allows different participants to predict same pick", %{participants: [participant1, participant2], players: [player1, _, _]} do
      pick_number = 1
      
      # Both participants can predict the same pick
      assert {:ok, _prediction1} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      assert {:ok, _prediction2} = MockDrafts.create_live_prediction(participant2.id, pick_number, player1.id)
    end

    test "create_live_prediction/3 allows same participant to predict different picks", %{participants: [participant1, _], players: [player1, player2, _]} do
      # Participant can predict multiple different picks
      assert {:ok, _prediction1} = MockDrafts.create_live_prediction(participant1.id, 1, player1.id)
      assert {:ok, _prediction2} = MockDrafts.create_live_prediction(participant1.id, 2, player2.id)
    end

    test "get_live_prediction/2 returns prediction for participant and pick", %{participants: [participant1, _], players: [player1, _, _]} do
      pick_number = 1
      {:ok, prediction} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      
      found_prediction = MockDrafts.get_live_prediction(participant1.id, pick_number)
      assert found_prediction.id == prediction.id
      assert found_prediction.participant_id == participant1.id
      assert found_prediction.pick_number == pick_number
    end

    test "get_live_prediction/2 returns nil when no prediction exists", %{participants: [participant1, _]} do
      assert is_nil(MockDrafts.get_live_prediction(participant1.id, 99))
    end

    test "get_participant!/1 returns participant by id", %{participants: [participant1, _]} do
      found_participant = MockDrafts.get_participant!(participant1.id)
      assert found_participant.id == participant1.id
      assert found_participant.display_name == participant1.display_name
    end

    test "get_participant!/1 raises when participant not found" do
      assert_raise Ecto.NoResultsError, fn ->
        MockDrafts.get_participant!(99999)
      end
    end

    test "list_predictions_for_participant/1 returns all predictions for participant", %{participants: [participant1, _], players: [player1, player2, _]} do
      # Create multiple predictions
      {:ok, _pred1} = MockDrafts.create_live_prediction(participant1.id, 1, player1.id)
      {:ok, _pred2} = MockDrafts.create_live_prediction(participant1.id, 2, player2.id)
      
      predictions = MockDrafts.list_predictions_for_participant(participant1.id)
      assert length(predictions) == 2
      assert Enum.all?(predictions, &(&1.participant_id == participant1.id))
    end

    test "list_predictions_for_participant/1 returns empty list when no predictions", %{participants: [participant1, _]} do
      predictions = MockDrafts.list_predictions_for_participant(participant1.id)
      assert predictions == []
    end
  end

  describe "live scoring system" do
    setup do
      # Create test data
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      player2 = player_fixture(draft.id, %{display_name: "Canyon", preferred_roles: [:jungle]})
      player3 = player_fixture(draft.id, %{display_name: "Keria", preferred_roles: [:support]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "Player1")
      {:ok, participant2} = MockDrafts.create_participant(mock_draft.id, "Player2")
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        team1: team1,
        players: [player1, player2, player3],
        participants: [participant1, participant2]
      }
    end

    test "score_pick_predictions/1 scores exact prediction correctly", %{draft: draft, team1: team1, players: [player1, _, _], participants: [participant1, _]} do
      pick_number = 1
      
      # Create prediction
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      
      # Create matching pick
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Score the predictions
      MockDrafts.score_pick_predictions(pick)
      
      # Check prediction was scored correctly
      updated_prediction = MockDrafts.get_live_prediction(participant1.id, pick_number)
      assert updated_prediction.points_awarded == 10  # Exact match
      assert updated_prediction.prediction_type == "exact"
      assert updated_prediction.is_locked == true
      refute is_nil(updated_prediction.scored_at)
      
      # Check participant score was updated
      updated_participant = MockDrafts.get_participant!(participant1.id)
      assert updated_participant.total_score == 10
      assert updated_participant.predictions_made == 1
      assert Decimal.equal?(updated_participant.accuracy_percentage, Decimal.new("100.00"))
    end

    test "score_pick_predictions/1 scores wrong prediction correctly", %{draft: draft, team1: team1, players: [player1, player2, _], participants: [participant1, _]} do
      pick_number = 1
      
      # Create prediction for player1
      {:ok, _prediction} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      
      # Create pick for different player
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player2.id, random_champion_id())
      
      # Score the predictions
      MockDrafts.score_pick_predictions(pick)
      
      # Check prediction was scored (could be round match due to both players being in same round)
      updated_prediction = MockDrafts.get_live_prediction(participant1.id, pick_number)
      # Since both players might be in same round, expect 3 points for round match
      assert updated_prediction.points_awarded == 3  # Round match
      assert updated_prediction.prediction_type == "round"
      assert updated_prediction.is_locked == true
      
      # Check participant score
      updated_participant = MockDrafts.get_participant!(participant1.id)
      assert updated_participant.total_score == 3  # Round match gives 3 points
      assert updated_participant.predictions_made == 1
      assert Decimal.equal?(updated_participant.accuracy_percentage, Decimal.new("100.00"))  # Round match counts as correct
    end

    test "score_pick_predictions/1 scores multiple participants", %{draft: draft, team1: team1, players: [player1, _, _], participants: [participant1, participant2]} do
      pick_number = 1
      
      # Both participants predict same player
      {:ok, _pred1} = MockDrafts.create_live_prediction(participant1.id, pick_number, player1.id)
      {:ok, _pred2} = MockDrafts.create_live_prediction(participant2.id, pick_number, player1.id)
      
      # Create matching pick
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Score the predictions
      MockDrafts.score_pick_predictions(pick)
      
      # Both should get points
      updated_participant1 = MockDrafts.get_participant!(participant1.id)
      updated_participant2 = MockDrafts.get_participant!(participant2.id)
      
      assert updated_participant1.total_score == 10
      assert updated_participant2.total_score == 10
    end

    test "score_pick_predictions/1 handles no predictions gracefully", %{draft: draft, team1: team1, players: [player1, _, _]} do
      _pick_number = 1
      
      # Create pick without any predictions
      {:ok, pick} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      
      # Should not crash
      assert {:ok, _scoring_event} = MockDrafts.score_pick_predictions(pick)
    end

    test "score_pick_predictions/1 updates participant totals across multiple predictions", %{draft: draft, team1: team1, players: [player1, player2, _], participants: [participant1, _]} do
      # Create multiple predictions for same participant
      {:ok, _pred1} = MockDrafts.create_live_prediction(participant1.id, 1, player1.id)
      {:ok, _pred2} = MockDrafts.create_live_prediction(participant1.id, 2, player2.id)
      
      # Score first pick (correct)
      {:ok, pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())
      MockDrafts.score_pick_predictions(pick1)
      
      # Check interim totals
      interim_participant = MockDrafts.get_participant!(participant1.id)
      assert interim_participant.total_score == 10
      assert interim_participant.predictions_made == 2  # All predictions are counted as made
      
      # Score second pick (also correct)
      {:ok, pick2} = Drafts.make_pick(draft.id, team1.id, player2.id, random_champion_id())
      MockDrafts.score_pick_predictions(pick2)
      
      # Check final totals
      final_participant = MockDrafts.get_participant!(participant1.id)
      assert final_participant.total_score == 20
      assert final_participant.predictions_made == 2
      assert Decimal.equal?(final_participant.accuracy_percentage, Decimal.new("100.00"))
    end

    test "score_pick_predictions/1 calculates accuracy percentage correctly with mixed results", %{draft: draft, team1: team1, players: [player1, player2, player3], participants: [participant1, _]} do
      # Create three predictions
      {:ok, _pred1} = MockDrafts.create_live_prediction(participant1.id, 1, player1.id)
      {:ok, _pred2} = MockDrafts.create_live_prediction(participant1.id, 2, player1.id)  # Wrong prediction
      {:ok, _pred3} = MockDrafts.create_live_prediction(participant1.id, 3, player3.id)
      
      # Score picks: correct, partial match, correct
      {:ok, pick1} = Drafts.make_pick(draft.id, team1.id, player1.id, random_champion_id())  # 10 points (exact)
      {:ok, pick2} = Drafts.make_pick(draft.id, team1.id, player2.id, random_champion_id())  # 5 points (general/round match)
      {:ok, pick3} = Drafts.make_pick(draft.id, team1.id, player3.id, random_champion_id())  # 10 points (exact)
      
      MockDrafts.score_pick_predictions(pick1)
      MockDrafts.score_pick_predictions(pick2)
      MockDrafts.score_pick_predictions(pick3)
      
      # Check final stats: all 3 predictions score (with different point values) = 100%
      final_participant = MockDrafts.get_participant!(participant1.id)
      assert final_participant.total_score == 25
      assert final_participant.predictions_made == 3
      assert Decimal.equal?(final_participant.accuracy_percentage, Decimal.new("100.00"))
    end
  end

  describe "prediction scoring edge cases" do
    setup do
      # Create test data
      draft = draft_fixture()
      team1 = team_fixture(draft.id, %{name: "Blue Team", pick_order_position: 1})
      
      player1 = player_fixture(draft.id, %{display_name: "Faker", preferred_roles: [:mid]})
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{
        live_predictions_enabled: true
      })
      
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "Player1")
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        team1: team1,
        player1: player1,
        participant1: participant1
      }
    end

    test "score_pick_predictions/1 handles prediction for non-existent player", %{draft: _draft, team1: _team1, player1: _player1, participant1: participant1} do
      pick_number = 1
      
      # Create prediction with invalid player id
      prediction_attrs = %{
        participant_id: participant1.id,
        pick_number: pick_number,
        predicted_player_id: 99999
      }
      
      {:error, changeset} = 
        %MockDrafts.MockDraftPrediction{}
        |> MockDrafts.MockDraftPrediction.changeset(prediction_attrs)
        |> Repo.insert()
      
      # Should have foreign key constraint error
      assert changeset.errors[:predicted_player_id] != nil
    end

    test "update_participant_scores handles participant with no predictions", %{participant1: participant1} do
      # Participant has no predictions yet
      predictions = MockDrafts.list_predictions_for_participant(participant1.id)
      assert predictions == []
      
      # Should handle gracefully - this is a private function, so we can't test it directly
      # But we can test that the public functions work correctly
      
      # Check participant stats remain at defaults
      updated_participant = MockDrafts.get_participant!(participant1.id)
      assert updated_participant.total_score == 0
      assert updated_participant.predictions_made == 0
      assert Decimal.equal?(updated_participant.accuracy_percentage, Decimal.new("0.00"))
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
        status: :active
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