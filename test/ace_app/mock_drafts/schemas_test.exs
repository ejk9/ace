defmodule AceApp.MockDrafts.SchemasTest do
  use AceApp.DataCase

  alias AceApp.MockDrafts.{
    MockDraft,
    MockDraftSubmission,
    PredictedPick,
    MockDraftParticipant,
    MockDraftPrediction,
    PredictionScoringEvent
  }

  describe "MockDraft schema" do
    test "changeset with valid attributes" do
      attrs = %{
        draft_id: 1,
        mock_draft_token: "valid_token_123",
        predraft_enabled: true,
        live_enabled: true,
        max_predraft_participants: 50,
        max_live_participants: 100,
        submission_deadline: DateTime.utc_now() |> DateTime.add(86400, :second),
        scoring_rules: %{"exact_pick" => 10, "general" => 5}
      }

      changeset = MockDraft.changeset(%MockDraft{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires draft_id and mock_draft_token" do
      changeset = MockDraft.changeset(%MockDraft{}, %{})
      
      assert changeset.errors[:draft_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:mock_draft_token] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates at least one track is enabled" do
      attrs = %{
        draft_id: 1,
        mock_draft_token: "valid_token_123",
        predraft_enabled: false,
        live_enabled: false
      }

      changeset = MockDraft.changeset(%MockDraft{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:predraft_enabled] == {"at least one track must be enabled", []}
    end

    test "changeset validates positive participant limits" do
      attrs = %{
        draft_id: 1,
        mock_draft_token: "valid_token_123",
        max_predraft_participants: 0,
        max_live_participants: -1
      }

      changeset = MockDraft.changeset(%MockDraft{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:max_predraft_participants] == {"must be greater than 0", [validation: :number, kind: :greater_than, number: 0]}
      assert changeset.errors[:max_live_participants] == {"must be greater than 0", [validation: :number, kind: :greater_than, number: 0]}
    end
  end

  describe "MockDraftSubmission schema" do
    test "changeset with valid attributes" do
      attrs = %{
        mock_draft_id: 1,
        participant_name: "Test Player",
        submission_token: "valid_token_123",
        is_submitted: false,
        total_accuracy_score: 85,
        overall_accuracy_percentage: Decimal.new("85.5")
      }

      changeset = MockDraftSubmission.changeset(%MockDraftSubmission{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires required fields" do
      changeset = MockDraftSubmission.changeset(%MockDraftSubmission{}, %{})
      
      assert changeset.errors[:mock_draft_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:participant_name] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:submission_token] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates participant_name length" do
      attrs = %{
        mock_draft_id: 1,
        participant_name: "",
        submission_token: "valid_token_123"
      }

      changeset = MockDraftSubmission.changeset(%MockDraftSubmission{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:participant_name] == {"should be at least 1 character(s)", [count: 1, validation: :length, kind: :min, type: :string]}
    end

    test "changeset validates accuracy percentage range" do
      attrs = %{
        mock_draft_id: 1,
        participant_name: "Test Player",
        submission_token: "valid_token_123",
        overall_accuracy_percentage: Decimal.new("150.0")
      }

      changeset = MockDraftSubmission.changeset(%MockDraftSubmission{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:overall_accuracy_percentage] == {"must be less than or equal to 100", [validation: :number, kind: :less_than_or_equal_to, number: 100]}
    end
  end

  describe "PredictedPick schema" do
    test "changeset with valid attributes" do
      attrs = %{
        submission_id: 1,
        pick_number: 5,
        team_id: 2,
        predicted_player_id: 3,
        actual_player_id: 3,
        points_awarded: 10,
        is_correct: true,
        prediction_type: "exact"
      }

      changeset = PredictedPick.changeset(%PredictedPick{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires required fields" do
      changeset = PredictedPick.changeset(%PredictedPick{}, %{})
      
      assert changeset.errors[:submission_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:pick_number] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:team_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:predicted_player_id] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates pick_number is positive" do
      attrs = %{
        submission_id: 1,
        pick_number: 0,
        team_id: 2,
        predicted_player_id: 3
      }

      changeset = PredictedPick.changeset(%PredictedPick{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:pick_number] == {"must be greater than 0", [validation: :number, kind: :greater_than, number: 0]}
    end

    test "changeset validates prediction_type inclusion" do
      attrs = %{
        submission_id: 1,
        pick_number: 1,
        team_id: 2,
        predicted_player_id: 3,
        prediction_type: "invalid_type"
      }

      changeset = PredictedPick.changeset(%PredictedPick{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:prediction_type] == {"is invalid", [validation: :inclusion, enum: ["exact", "right_player", "right_round", "role_match", "miss"]]}
    end
  end

  describe "MockDraftParticipant schema" do
    test "changeset with valid attributes" do
      attrs = %{
        mock_draft_id: 1,
        display_name: "Live Player",
        participant_token: "valid_token_123",
        total_score: 75,
        predictions_made: 10,
        accuracy_percentage: Decimal.new("75.0"),
        joined_at: DateTime.utc_now()
      }

      changeset = MockDraftParticipant.changeset(%MockDraftParticipant{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires required fields" do
      changeset = MockDraftParticipant.changeset(%MockDraftParticipant{}, %{})
      
      assert changeset.errors[:mock_draft_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:display_name] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:participant_token] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates score and predictions are non-negative" do
      attrs = %{
        mock_draft_id: 1,
        display_name: "Live Player",
        participant_token: "valid_token_123",
        total_score: -5,
        predictions_made: -1
      }

      changeset = MockDraftParticipant.changeset(%MockDraftParticipant{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:total_score] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
      assert changeset.errors[:predictions_made] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
    end
  end

  describe "MockDraftPrediction schema" do
    test "changeset with valid attributes" do
      attrs = %{
        participant_id: 1,
        pick_number: 5,
        predicted_player_id: 3,
        points_awarded: 10,
        prediction_type: "exact",
        is_locked: true,
        predicted_at: DateTime.utc_now(),
        scored_at: DateTime.utc_now()
      }

      changeset = MockDraftPrediction.changeset(%MockDraftPrediction{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires required fields" do
      changeset = MockDraftPrediction.changeset(%MockDraftPrediction{}, %{})
      
      assert changeset.errors[:participant_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:pick_number] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:predicted_player_id] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates prediction_type inclusion" do
      attrs = %{
        participant_id: 1,
        pick_number: 1,
        predicted_player_id: 3,
        prediction_type: "invalid_type"
      }

      changeset = MockDraftPrediction.changeset(%MockDraftPrediction{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:prediction_type] == {"is invalid", [validation: :inclusion, enum: ["exact", "general", "round", "miss"]]}
    end
  end

  describe "PredictionScoringEvent schema" do
    test "changeset with valid attributes" do
      attrs = %{
        mock_draft_id: 1,
        pick_number: 5,
        actual_player_id: 3,
        total_predraft_predictions: 25,
        correct_predraft_predictions: 10,
        total_live_predictions: 50,
        correct_live_predictions: 15,
        scoring_timestamp: DateTime.utc_now()
      }

      changeset = PredictionScoringEvent.changeset(%PredictionScoringEvent{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires required fields" do
      changeset = PredictionScoringEvent.changeset(%PredictionScoringEvent{}, %{})
      
      assert changeset.errors[:mock_draft_id] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:pick_number] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:actual_player_id] == {"can't be blank", [validation: :required]}
    end

    test "changeset validates prediction counts are non-negative" do
      attrs = %{
        mock_draft_id: 1,
        pick_number: 1,
        actual_player_id: 3,
        total_predraft_predictions: -1,
        correct_predraft_predictions: -1,
        total_live_predictions: -1,
        correct_live_predictions: -1
      }

      changeset = PredictionScoringEvent.changeset(%PredictionScoringEvent{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:total_predraft_predictions] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
      assert changeset.errors[:correct_predraft_predictions] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
      assert changeset.errors[:total_live_predictions] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
      assert changeset.errors[:correct_live_predictions] == {"must be greater than or equal to 0", [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
    end
  end
end