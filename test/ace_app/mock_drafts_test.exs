defmodule AceApp.MockDraftsTest do
  use AceApp.DataCase

  alias AceApp.MockDrafts
  alias AceApp.MockDrafts.{MockDraft, MockDraftSubmission, PredictedPick, MockDraftParticipant, MockDraftPrediction}
  alias AceApp.{Drafts, Repo}

  describe "mock_drafts" do
    setup do
      draft = draft_fixture()
      %{draft: draft}
    end

    test "create_mock_draft/2 creates a mock draft with valid attributes", %{draft: draft} do
      attrs = %{
        predraft_enabled: true,
        live_enabled: true,
        submission_deadline: DateTime.add(DateTime.utc_now(), 86400, :second)
      }

      assert {:ok, %MockDraft{} = mock_draft} = MockDrafts.create_mock_draft(draft.id, attrs)
      assert mock_draft.draft_id == draft.id
      assert mock_draft.predraft_enabled == true
      assert mock_draft.live_enabled == true
      assert mock_draft.mock_draft_token != nil
      assert String.length(mock_draft.mock_draft_token) > 0
    end

    test "create_mock_draft/2 creates with default values when no attrs provided", %{draft: draft} do
      assert {:ok, %MockDraft{} = mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      assert mock_draft.predraft_enabled == true
      assert mock_draft.live_enabled == true
      assert mock_draft.max_predraft_participants == 100
      assert mock_draft.max_live_participants == 100
    end

    test "create_mock_draft/2 generates unique tokens" do
      draft1 = draft_fixture()
      draft2 = draft_fixture()

      {:ok, mock_draft1} = MockDrafts.create_mock_draft(draft1.id, %{})
      {:ok, mock_draft2} = MockDrafts.create_mock_draft(draft2.id, %{})

      assert mock_draft1.mock_draft_token != mock_draft2.mock_draft_token
    end

    test "get_mock_draft_by_token/1 returns mock draft when token exists", %{draft: draft} do
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      
      found_mock_draft = MockDrafts.get_mock_draft_by_token(mock_draft.mock_draft_token)
      assert found_mock_draft.id == mock_draft.id
    end

    test "get_mock_draft_by_token/1 returns nil when token doesn't exist" do
      assert MockDrafts.get_mock_draft_by_token("nonexistent") == nil
    end

    test "get_mock_draft_by_token!/1 returns mock draft with preloaded associations", %{draft: draft} do
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      
      found_mock_draft = MockDrafts.get_mock_draft_by_token!(mock_draft.mock_draft_token)
      assert found_mock_draft.id == mock_draft.id
      assert Ecto.assoc_loaded?(found_mock_draft.draft)
      assert Ecto.assoc_loaded?(found_mock_draft.submissions)
      assert Ecto.assoc_loaded?(found_mock_draft.participants)
    end

    test "update_mock_draft/2 updates mock draft with valid attributes", %{draft: draft} do
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      
      update_attrs = %{
        predraft_enabled: false,
        max_predraft_participants: 50
      }

      assert {:ok, updated_mock_draft} = MockDrafts.update_mock_draft(mock_draft, update_attrs)
      assert updated_mock_draft.predraft_enabled == false
      assert updated_mock_draft.max_predraft_participants == 50
    end
  end

  describe "submissions (Track 1)" do
    setup do
      draft = draft_fixture()
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      %{draft: draft, mock_draft: mock_draft}
    end

    test "create_submission/2 creates a submission with valid attributes", %{mock_draft: mock_draft} do
      participant_name = "TestPlayer"

      assert {:ok, %MockDraftSubmission{} = submission} = 
        MockDrafts.create_submission(mock_draft.id, participant_name)
      
      assert submission.mock_draft_id == mock_draft.id
      assert submission.participant_name == participant_name
      assert submission.submission_token != nil
      assert submission.is_submitted == false
      assert submission.total_accuracy_score == 0
    end

    test "create_submission/2 prevents duplicate participant names", %{mock_draft: mock_draft} do
      participant_name = "TestPlayer"

      {:ok, _submission1} = MockDrafts.create_submission(mock_draft.id, participant_name)
      
      result = MockDrafts.create_submission(mock_draft.id, participant_name)
      assert {:error, changeset} = result
      
      # Check all possible error fields
      refute changeset.valid?
      # The constraint might be on mock_draft_id_participant_name field
      assert changeset.errors != []
    end

    test "get_submission_by_token/1 returns submission when token exists", %{mock_draft: mock_draft} do
      {:ok, submission} = MockDrafts.create_submission(mock_draft.id, "TestPlayer")
      
      found_submission = MockDrafts.get_submission_by_token(submission.submission_token)
      assert found_submission.id == submission.id
    end

    test "submit_complete_draft/1 marks submission as submitted", %{mock_draft: mock_draft} do
      {:ok, submission} = MockDrafts.create_submission(mock_draft.id, "TestPlayer")
      
      assert {:ok, updated_submission} = MockDrafts.submit_complete_draft(submission.id)
      assert updated_submission.is_submitted == true
      assert updated_submission.submitted_at != nil
    end

    test "list_submissions/1 returns all submissions for mock draft ordered by score", %{mock_draft: mock_draft} do
      {:ok, submission1} = MockDrafts.create_submission(mock_draft.id, "Player1")
      {:ok, submission2} = MockDrafts.create_submission(mock_draft.id, "Player2")

      # Update scores to test ordering
      Repo.update!(MockDraftSubmission.changeset(submission1, %{total_accuracy_score: 50}))
      Repo.update!(MockDraftSubmission.changeset(submission2, %{total_accuracy_score: 75}))

      submissions = MockDrafts.list_submissions(mock_draft.id)
      assert length(submissions) == 2
      assert hd(submissions).total_accuracy_score == 75  # Highest score first
    end
  end

  describe "predicted_picks" do
    setup do
      draft = draft_fixture()
      team = team_fixture(draft.id)
      player = player_fixture(draft.id)
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      {:ok, submission} = MockDrafts.create_submission(mock_draft.id, "TestPlayer")
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        submission: submission,
        team: team,
        player: player
      }
    end

    test "upsert_predicted_pick/4 creates new predicted pick", %{submission: submission, team: team, player: player} do
      pick_number = 1

      assert {:ok, %PredictedPick{} = predicted_pick} = 
        MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player.id)
      
      assert predicted_pick.submission_id == submission.id
      assert predicted_pick.pick_number == pick_number
      assert predicted_pick.team_id == team.id
      assert predicted_pick.predicted_player_id == player.id
      assert predicted_pick.points_awarded == 0
      assert predicted_pick.is_correct == false
    end

    test "upsert_predicted_pick/4 updates existing predicted pick", %{submission: submission, team: team, player: player, draft: draft} do
      pick_number = 1
      player2 = player_fixture(draft.id)

      # Create initial pick
      {:ok, predicted_pick} = MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player.id)
      initial_id = predicted_pick.id

      # Update the same pick number with different player
      {:ok, updated_pick} = MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player2.id)
      
      assert updated_pick.id == initial_id  # Same record updated
      assert updated_pick.predicted_player_id == player2.id
    end

    test "upsert_predicted_pick/4 enforces unique constraint on submission_id and pick_number", %{submission: submission, team: team, player: player} do
      pick_number = 1

      # Create first pick
      {:ok, _predicted_pick} = MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player.id)
      
      # Updating should work (upsert behavior)
      assert {:ok, _updated_pick} = MockDrafts.upsert_predicted_pick(submission.id, pick_number, team.id, player.id)
    end
  end

  describe "live_predictions (Track 2)" do
    setup do
      draft = draft_fixture()
      player = player_fixture(draft.id)
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        player: player
      }
    end

    test "create_participant/2 creates a participant with valid attributes", %{mock_draft: mock_draft} do
      display_name = "LivePlayer"

      assert {:ok, %MockDraftParticipant{} = participant} = 
        MockDrafts.create_participant(mock_draft.id, display_name)
      
      assert participant.mock_draft_id == mock_draft.id
      assert participant.display_name == display_name
      assert participant.participant_token != nil
      assert participant.total_score == 0
      assert participant.predictions_made == 0
    end

    test "create_participant/2 prevents duplicate display names", %{mock_draft: mock_draft} do
      display_name = "LivePlayer"

      {:ok, _participant1} = MockDrafts.create_participant(mock_draft.id, display_name)
      
      result = MockDrafts.create_participant(mock_draft.id, display_name)
      assert {:error, changeset} = result
      
      # Check all possible error fields
      refute changeset.valid?
      assert changeset.errors != []
    end

    test "get_participant_by_token/1 returns participant when token exists", %{mock_draft: mock_draft} do
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "LivePlayer")
      
      found_participant = MockDrafts.get_participant_by_token(participant.participant_token)
      assert found_participant.id == participant.id
    end

    test "create_live_prediction/3 creates a prediction with valid attributes", %{mock_draft: mock_draft, player: player} do
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "LivePlayer")
      pick_number = 1

      assert {:ok, %MockDraftPrediction{} = prediction} = 
        MockDrafts.create_live_prediction(participant.id, pick_number, player.id)
      
      assert prediction.participant_id == participant.id
      assert prediction.pick_number == pick_number
      assert prediction.predicted_player_id == player.id
      assert prediction.points_awarded == 0
      assert prediction.is_locked == false
    end

    test "list_participants/1 returns all participants for mock draft ordered by score", %{mock_draft: mock_draft} do
      {:ok, participant1} = MockDrafts.create_participant(mock_draft.id, "Player1")
      {:ok, participant2} = MockDrafts.create_participant(mock_draft.id, "Player2")

      # Update scores to test ordering
      Repo.update!(MockDraftParticipant.changeset(participant1, %{total_score: 50}))
      Repo.update!(MockDraftParticipant.changeset(participant2, %{total_score: 75}))

      participants = MockDrafts.list_participants(mock_draft.id)
      assert length(participants) == 2
      assert hd(participants).total_score == 75  # Highest score first
    end
  end

  describe "scoring_system" do
    setup do
      draft = draft_fixture()
      team = team_fixture(draft.id)
      player1 = player_fixture(draft.id)
      player2 = player_fixture(draft.id)
      
      {:ok, mock_draft} = MockDrafts.create_mock_draft(draft.id, %{})
      {:ok, submission} = MockDrafts.create_submission(mock_draft.id, "TestPlayer")
      {:ok, participant} = MockDrafts.create_participant(mock_draft.id, "LivePlayer")
      
      # Create some predicted picks
      {:ok, _predicted_pick} = MockDrafts.upsert_predicted_pick(submission.id, 1, team.id, player1.id)
      {:ok, _live_prediction} = MockDrafts.create_live_prediction(participant.id, 1, player1.id)
      
      %{
        draft: draft,
        mock_draft: mock_draft,
        submission: submission,
        participant: participant,
        team: team,
        player1: player1,
        player2: player2
      }
    end

    test "score_pick_predictions/1 processes scoring for both tracks", %{draft: draft, team: team, player1: player1} do
      # Create a pick that matches our predictions
      pick = pick_fixture(draft.id, team.id, player1.id, 1)

      # This should trigger scoring for both submission and live predictions
      assert {:ok, _scoring_event} = MockDrafts.score_pick_predictions(pick)

      # Verify that predicted picks were scored
      predicted_pick = Repo.get_by(PredictedPick, pick_number: 1)
      assert predicted_pick.actual_player_id == player1.id
      assert predicted_pick.points_awarded > 0
      assert predicted_pick.is_correct == true

      # Verify that live predictions were scored
      live_prediction = Repo.get_by(MockDraftPrediction, pick_number: 1)
      assert live_prediction.points_awarded > 0
      assert live_prediction.is_locked == true
      assert live_prediction.scored_at != nil
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

  defp team_fixture(draft_id, attrs \\ %{}) do
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

  defp player_fixture(draft_id, attrs \\ %{}) do
    {:ok, player} = 
      attrs
      |> Enum.into(%{
        display_name: "Test Player #{System.unique_integer()}",
        preferred_roles: [:mid, :adc]
      })
      |> then(&Drafts.create_player(draft_id, &1))

    player
  end

  defp pick_fixture(draft_id, team_id, player_id, pick_number) do
    %AceApp.Drafts.Pick{
      draft_id: draft_id,
      team_id: team_id,
      player_id: player_id,
      pick_number: pick_number,
      round_number: 1,
      picked_at: DateTime.utc_now()
    }
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end