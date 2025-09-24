defmodule AceApp.MockDrafts do
  @moduledoc """
  The MockDrafts context for managing mock draft prediction systems.
  
  Supports two tracks:
  - Track 1: Complete draft submissions (pre-draft predictions)
  - Track 2: Real-time live predictions during draft
  """

  import Ecto.Query, warn: false
  alias AceApp.Repo
  alias AceApp.MockDrafts.{MockDraft, MockDraftSubmission, PredictedPick, MockDraftParticipant, MockDraftPrediction, PredictionScoringEvent}

  @doc """
  Creates a mock draft for the given draft.
  """
  def create_mock_draft(draft_id, attrs \\ %{}) do
    attrs = 
      attrs
      |> Map.put_new(:draft_id, draft_id)
      |> Map.put_new(:mock_draft_token, generate_token())

    %MockDraft{}
    |> MockDraft.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a mock draft by token.
  """
  def get_mock_draft_by_token(token) do
    Repo.get_by(MockDraft, mock_draft_token: token)
  end

  @doc """
  Gets a mock draft by token with preloaded associations.
  """
  def get_mock_draft_by_token!(token) do
    MockDraft
    |> where([md], md.mock_draft_token == ^token)
    |> preload([:draft, :submissions, :participants])
    |> Repo.one!()
  end

  @doc """
  Gets a mock draft by ID.
  """
  def get_mock_draft!(id) do
    Repo.get!(MockDraft, id)
  end

  @doc """
  Gets the mock draft for a given draft (one-to-one relationship).
  """
  def get_mock_draft_for_draft(draft_id) do
    MockDraft
    |> where([md], md.draft_id == ^draft_id)
    |> Repo.one()
  end

  @doc """
  Gets the mock draft for a given draft, creating it if it doesn't exist.
  """
  def get_or_create_mock_draft_for_draft(draft_id) do
    case get_mock_draft_for_draft(draft_id) do
      nil -> create_mock_draft(draft_id, %{})
      mock_draft -> {:ok, mock_draft}
    end
  end

  @doc """
  Lists all mock drafts for a given draft.
  @deprecated Use get_mock_draft_for_draft/1 instead for one-to-one relationship
  """
  def list_mock_drafts_for_draft(draft_id) do
    case get_mock_draft_for_draft(draft_id) do
      nil -> []
      mock_draft -> [mock_draft]
    end
  end

  @doc """
  Updates a mock draft.
  """
  def update_mock_draft(%MockDraft{} = mock_draft, attrs) do
    mock_draft
    |> MockDraft.changeset(attrs)
    |> Repo.update()
  end

  ## Track 1: Complete Draft Submissions

  @doc """
  Lists all completed submissions for a mock draft, ordered by score descending.
  Only returns submissions that have been fully submitted (is_submitted: true).
  """
  def list_submissions_for_mock_draft(mock_draft_id) do
    MockDraftSubmission
    |> where([s], s.mock_draft_id == ^mock_draft_id and s.is_submitted == true)
    |> order_by([s], desc: s.total_accuracy_score)
    |> Repo.all()
  end

  @doc """
  Lists all submissions for a mock draft (including incomplete ones), ordered by score descending.
  """
  def list_all_submissions_for_mock_draft(mock_draft_id) do
    MockDraftSubmission
    |> where([s], s.mock_draft_id == ^mock_draft_id)
    |> order_by([s], desc: s.total_accuracy_score)
    |> Repo.all()
  end

  @doc """
  Creates a submission for Track 1 (complete draft predictions).
  """
  def create_submission(mock_draft_id, participant_name) do
    %MockDraftSubmission{}
    |> MockDraftSubmission.changeset(%{
      mock_draft_id: mock_draft_id,
      participant_name: participant_name,
      submission_token: generate_token()
    })
    |> Repo.insert()
  end

  @doc """
  Gets a submission by token.
  """
  def get_submission_by_token(token) do
    Repo.get_by(MockDraftSubmission, submission_token: token)
  end

  @doc """
  Find existing submission by mock draft ID and participant name.
  """
  def find_existing_submission(mock_draft_id, participant_name) do
    MockDraftSubmission
    |> where([s], s.mock_draft_id == ^mock_draft_id and s.participant_name == ^participant_name)
    |> Repo.one()
  end

  @doc """
  List predictions for a participant.
  """
  def list_predictions_for_participant(participant_id) do
    MockDraftPrediction
    |> where([p], p.participant_id == ^participant_id)
    |> order_by([p], p.pick_number)
    |> Repo.all()
  end

  @doc """
  Gets a submission by token with preloaded predictions.
  """
  def get_submission_by_token!(token) do
    MockDraftSubmission
    |> where([s], s.submission_token == ^token)
    |> preload([predicted_picks: [:predicted_player, :team, :actual_player]])
    |> Repo.one!()
  end

  @doc """
  Lists all predicted picks for a submission.
  """
  def list_predicted_picks_for_submission(submission_id) do
    PredictedPick
    |> where([p], p.submission_id == ^submission_id)
    |> order_by([p], p.pick_number)
    |> Repo.all()
  end

  @doc """
  Creates or updates a predicted pick for a submission.
  """
  def upsert_predicted_pick(submission_id, pick_number, team_id, predicted_player_id) do
    attrs = %{
      submission_id: submission_id,
      pick_number: pick_number,
      team_id: team_id,
      predicted_player_id: predicted_player_id
    }

    case Repo.get_by(PredictedPick, submission_id: submission_id, pick_number: pick_number) do
      nil ->
        %PredictedPick{}
        |> PredictedPick.changeset(attrs)
        |> Repo.insert()
      
      existing_pick ->
        existing_pick
        |> PredictedPick.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Submits a complete draft (locks in all predictions).
  """
  def submit_complete_draft(submission_id) do
    submission = Repo.get!(MockDraftSubmission, submission_id)
    
    submission
    |> MockDraftSubmission.changeset(%{
      is_submitted: true,
      submitted_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Lists all submissions for a mock draft.
  """
  def list_submissions(mock_draft_id) do
    MockDraftSubmission
    |> where([s], s.mock_draft_id == ^mock_draft_id)
    |> order_by([s], [desc: s.overall_accuracy_percentage, desc: s.total_accuracy_score])
    |> preload([:predicted_picks])
    |> Repo.all()
  end

  ## Track 2: Live Predictions

  @doc """
  Lists all participants for a mock draft, ordered by score descending.
  """
  def list_participants_for_mock_draft(mock_draft_id) do
    MockDraftParticipant
    |> where([p], p.mock_draft_id == ^mock_draft_id)
    |> order_by([p], desc: p.total_score)
    |> Repo.all()
  end

  @doc """
  Creates a participant for Track 2 (live predictions).
  """
  def create_participant(mock_draft_id, display_name) do
    %MockDraftParticipant{}
    |> MockDraftParticipant.changeset(%{
      mock_draft_id: mock_draft_id,
      display_name: display_name,
      participant_token: generate_token()
    })
    |> Repo.insert()
  end

  @doc """
  Gets a participant by token.
  """
  def get_participant_by_token(token) do
    Repo.get_by(MockDraftParticipant, participant_token: token)
  end

  @doc """
  Gets a participant by ID.
  """
  def get_participant!(id) do
    Repo.get!(MockDraftParticipant, id)
  end

  @doc """
  Creates a live prediction.
  """
  def create_live_prediction(participant_id, pick_number, predicted_player_id) do
    %MockDraftPrediction{}
    |> MockDraftPrediction.changeset(%{
      participant_id: participant_id,
      pick_number: pick_number,
      predicted_player_id: predicted_player_id
    })
    |> Repo.insert()
  end

  @doc """
  Lists all participants for a mock draft.
  """
  def list_participants(mock_draft_id) do
    MockDraftParticipant
    |> where([p], p.mock_draft_id == ^mock_draft_id)
    |> order_by([p], [desc: p.total_score, desc: p.accuracy_percentage])
    |> Repo.all()
  end

  @doc """
  Gets a live prediction for a participant and pick number.
  """
  def get_live_prediction(participant_id, pick_number) do
    MockDraftPrediction
    |> where([p], p.participant_id == ^participant_id and p.pick_number == ^pick_number)
    |> Repo.one()
  end

  ## Scoring System

  @doc """
  Scores predictions when an actual pick is made.
  """
  def score_pick_predictions(pick) do
    # Score Track 1 submissions
    score_submission_predictions(pick)
    
    # Score Track 2 live predictions  
    score_live_predictions(pick)
    
    # Create scoring event for analytics
    create_scoring_event(pick)
  end

  defp score_submission_predictions(pick) do
    # Find all predicted picks for this pick number
    predicted_picks = 
      PredictedPick
      |> where([pp], pp.pick_number == ^pick.pick_number)
      |> join(:inner, [pp], s in MockDraftSubmission, on: pp.submission_id == s.id)
      |> join(:inner, [pp, s], md in MockDraft, on: s.mock_draft_id == md.id)
      |> where([pp, s, md], md.draft_id == ^pick.draft_id)
      |> preload([:submission])
      |> Repo.all()

    # Score each prediction
    Enum.each(predicted_picks, fn predicted_pick ->
      {points, prediction_type, is_correct} = calculate_submission_score(predicted_pick, pick)
      
      predicted_pick
      |> PredictedPick.changeset(%{
        actual_player_id: pick.player_id,
        points_awarded: points,
        prediction_type: prediction_type,
        is_correct: is_correct
      })
      |> Repo.update()
      
      # Update submission totals
      update_submission_scores(predicted_pick.submission)
    end)
  end

  defp score_live_predictions(pick) do
    # Use transaction to ensure data consistency
    Repo.transaction(fn ->
      # Find all live predictions for this pick number
      live_predictions = 
        MockDraftPrediction
        |> where([mp], mp.pick_number == ^pick.pick_number)
        |> join(:inner, [mp], p in MockDraftParticipant, on: mp.participant_id == p.id)
        |> join(:inner, [mp, p], md in MockDraft, on: p.mock_draft_id == md.id)
        |> where([mp, p, md], md.draft_id == ^pick.draft_id)
        |> preload([:participant])
        |> Repo.all()

      # Batch score all predictions
      score_predictions_batch(live_predictions, pick)
      
      # Batch update all participant scores
      participant_ids = live_predictions |> Enum.map(& &1.participant_id) |> Enum.uniq()
      update_participant_scores_batch(participant_ids)
    end)
  end

  defp score_predictions_batch(live_predictions, pick) do
    # Calculate scores for all predictions
    scored_predictions = 
      Enum.map(live_predictions, fn prediction ->
        {points, prediction_type} = calculate_live_score(prediction, pick)
        
        %{
          id: prediction.id,
          points_awarded: points,
          prediction_type: prediction_type,
          is_locked: true,
          scored_at: DateTime.utc_now()
        }
      end)

    # Batch update all predictions using individual updates in a more efficient way
    if length(scored_predictions) > 0 do
      now = DateTime.utc_now()
      
      # Use Repo.insert_all with ON CONFLICT for upsert behavior
      updates = Enum.map(scored_predictions, fn pred ->
        %{
          id: pred.id,
          points_awarded: pred.points_awarded,
          prediction_type: pred.prediction_type,
          is_locked: true,
          scored_at: now
        }
      end)
      
      # Use a more efficient approach with fewer individual updates
      Enum.each(updates, fn update ->
        from(mp in MockDraftPrediction, where: mp.id == ^update.id)
        |> Repo.update_all(
          set: [
            points_awarded: update.points_awarded,
            prediction_type: update.prediction_type,
            is_locked: true,
            scored_at: update.scored_at
          ]
        )
      end)
    end
  end

  defp update_participant_scores_batch(participant_ids) do
    if length(participant_ids) > 0 do
      # Get aggregated scores for all participants in a single query
      participant_stats = 
        from(mp in MockDraftPrediction,
          where: mp.participant_id in ^participant_ids,
          group_by: mp.participant_id,
          select: {mp.participant_id, coalesce(sum(mp.points_awarded), 0), count(mp.id), 
                   fragment("COUNT(CASE WHEN ? > 0 THEN 1 END)", mp.points_awarded)}
        )
        |> Repo.all()
        |> Enum.reduce(%{}, fn {participant_id, total_score, predictions_made, correct_predictions}, acc ->
          accuracy = if predictions_made > 0 do
            correct_predictions / predictions_made * 100
          else
            0
          end
          
          Map.put(acc, participant_id, %{
            total_score: total_score || 0,
            predictions_made: predictions_made,
            accuracy_percentage: accuracy
          })
        end)

      # Update each participant efficiently
      Enum.each(participant_ids, fn participant_id ->
        stats = Map.get(participant_stats, participant_id, %{
          total_score: 0,
          predictions_made: 0,
          accuracy_percentage: 0
        })
        
        from(p in MockDraftParticipant, where: p.id == ^participant_id)
        |> Repo.update_all(
          set: [
            total_score: stats.total_score,
            predictions_made: stats.predictions_made,
            accuracy_percentage: stats.accuracy_percentage
          ]
        )
      end)
    end
  end



  defp calculate_submission_score(predicted_pick, actual_pick) do
    cond do
      # Perfect pick - exact match
      predicted_pick.predicted_player_id == actual_pick.player_id ->
        {10, "exact", true}
      
      # Right player, wrong position
      player_picked_elsewhere?(predicted_pick.predicted_player_id, actual_pick.draft_id) ->
        {5, "right_player", false}
      
      # Right round (picks 1-10 = round 1, 11-20 = round 2, etc.)
      same_round?(predicted_pick.pick_number, actual_pick.pick_number) ->
        {3, "right_round", false}
      
      # TODO: Add role accuracy bonus logic
      true ->
        {0, "miss", false}
    end
  end

  defp calculate_live_score(prediction, actual_pick) do
    cond do
      # Exact pick prediction
      prediction.predicted_player_id == actual_pick.player_id ->
        {10, "exact"}
      
      # General selection (right player, wrong position in round)
      player_picked_in_round?(prediction.predicted_player_id, actual_pick.pick_number) ->
        {5, "general"}
      
      # Round prediction  
      same_round?(prediction.pick_number, actual_pick.pick_number) ->
        {3, "round"}
      
      true ->
        {0, "miss"}
    end
  end

  defp player_picked_elsewhere?(player_id, draft_id) do
    # Check if player was picked in this draft
    query = 
      from p in AceApp.Drafts.Pick,
      where: p.draft_id == ^draft_id and p.player_id == ^player_id

    Repo.exists?(query)
  end

  defp same_round?(pick_number_1, pick_number_2) do
    round_1 = div(pick_number_1 - 1, 10) + 1
    round_2 = div(pick_number_2 - 1, 10) + 1
    round_1 == round_2
  end

  defp player_picked_in_round?(player_id, target_pick_number) do
    round_start = (div(target_pick_number - 1, 10)) * 10 + 1
    round_end = round_start + 9
    
    # Check if player was picked in this round range by querying actual picks
    case from(p in AceApp.Drafts.Pick,
          where: p.player_id == ^player_id and 
                 p.pick_number >= ^round_start and 
                 p.pick_number <= ^round_end,
          select: count(p.id)) |> Repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  defp update_submission_scores(submission) do
    # Recalculate submission totals based on all predicted picks
    totals = 
      PredictedPick
      |> where([pp], pp.submission_id == ^submission.id)
      |> where([pp], not is_nil(pp.actual_player_id))
      |> select([pp], %{
        total_score: sum(pp.points_awarded),
        correct_picks: count(pp.id, :distinct),
        total_picks: count(pp.id, :distinct)
      })
      |> Repo.one()

    accuracy = if totals.total_picks > 0, do: totals.correct_picks / totals.total_picks * 100, else: 0

    submission
    |> MockDraftSubmission.changeset(%{
      total_accuracy_score: totals.total_score || 0,
      overall_accuracy_percentage: Decimal.from_float(accuracy)
    })
    |> Repo.update()
  end



  defp create_scoring_event(pick) do
    # Get statistics for this pick
    mock_draft = 
      MockDraft
      |> where([md], md.draft_id == ^pick.draft_id)
      |> Repo.one()

    if mock_draft do
      # Count predictions for this pick
      predraft_stats = count_predraft_predictions(mock_draft.id, pick.pick_number, pick.player_id)
      live_stats = count_live_predictions(mock_draft.id, pick.pick_number, pick.player_id)

      %PredictionScoringEvent{}
      |> PredictionScoringEvent.changeset(%{
        mock_draft_id: mock_draft.id,
        pick_number: pick.pick_number,
        actual_player_id: pick.player_id,
        total_predraft_predictions: predraft_stats.total,
        correct_predraft_predictions: predraft_stats.correct,
        total_live_predictions: live_stats.total,
        correct_live_predictions: live_stats.correct
      })
      |> Repo.insert()
    end
  end

  defp count_predraft_predictions(mock_draft_id, pick_number, actual_player_id) do
    stats = 
      PredictedPick
      |> join(:inner, [pp], s in MockDraftSubmission, on: pp.submission_id == s.id)
      |> where([pp, s], s.mock_draft_id == ^mock_draft_id and pp.pick_number == ^pick_number)
      |> select([pp], %{
        total: count(pp.id, :distinct),
        correct: fragment("COUNT(CASE WHEN ? = ? THEN 1 END)", pp.predicted_player_id, ^actual_player_id)
      })
      |> Repo.one()

    stats || %{total: 0, correct: 0}
  end

  defp count_live_predictions(mock_draft_id, pick_number, actual_player_id) do
    stats = 
      MockDraftPrediction
      |> join(:inner, [mp], p in MockDraftParticipant, on: mp.participant_id == p.id)
      |> where([mp, p], p.mock_draft_id == ^mock_draft_id and mp.pick_number == ^pick_number)
      |> select([mp], %{
        total: count(mp.id, :distinct),
        correct: fragment("COUNT(CASE WHEN ? = ? THEN 1 END)", mp.predicted_player_id, ^actual_player_id)
      })
      |> Repo.one()

    stats || %{total: 0, correct: 0}
  end

  ## Utility Functions

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end