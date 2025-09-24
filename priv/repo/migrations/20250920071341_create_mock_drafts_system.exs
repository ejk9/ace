defmodule AceApp.Repo.Migrations.CreateMockDraftsSystem do
  use Ecto.Migration

  def change do
    # Core mock draft configuration
    create table(:mock_drafts) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      
      # Dual track configuration
      add :predraft_enabled, :boolean, default: true
      add :live_enabled, :boolean, default: true
      
      # Access control
      add :mock_draft_token, :string, null: false
      
      # Track 1: Pre-draft settings
      add :submission_deadline, :utc_datetime
      add :max_predraft_participants, :integer, default: 100
      
      # Track 2: Live prediction settings  
      add :max_live_participants, :integer, default: 100
      
      # Scoring configuration
      add :scoring_rules, :map, default: %{}
      
      # Status
      add :is_enabled, :boolean, default: true
      
      timestamps()
    end

    # Track 1: Complete draft submissions
    create table(:mock_draft_submissions) do
      add :mock_draft_id, references(:mock_drafts, on_delete: :delete_all), null: false
      
      # Participant identity
      add :participant_name, :string, null: false
      add :submission_token, :string, null: false
      
      # Submission status
      add :is_submitted, :boolean, default: false
      add :submitted_at, :utc_datetime
      
      # Scoring results (calculated after draft)
      add :total_accuracy_score, :integer, default: 0
      add :pick_accuracy_score, :integer, default: 0
      add :team_accuracy_score, :integer, default: 0
      add :overall_accuracy_percentage, :decimal, precision: 5, scale: 2, default: 0.00
      
      timestamps()
    end

    # Track 1: Predicted picks for complete submissions
    create table(:predicted_picks) do
      add :submission_id, references(:mock_draft_submissions, on_delete: :delete_all), null: false
      
      # Prediction details
      add :pick_number, :integer, null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :predicted_player_id, references(:players, on_delete: :delete_all), null: false
      
      # Scoring results (filled when actual pick is made)
      add :actual_player_id, references(:players, on_delete: :delete_all)
      add :points_awarded, :integer, default: 0
      add :is_correct, :boolean, default: false
      add :prediction_type, :string # 'exact', 'right_player', 'right_round', 'role_match'
      
      timestamps()
    end

    # Track 2: Live prediction participants
    create table(:mock_draft_participants) do
      add :mock_draft_id, references(:mock_drafts, on_delete: :delete_all), null: false
      
      # Participant identity
      add :display_name, :string, null: false
      add :participant_token, :string, null: false
      
      # Live scoring stats
      add :total_score, :integer, default: 0
      add :predictions_made, :integer, default: 0
      add :accuracy_percentage, :decimal, precision: 5, scale: 2, default: 0.00
      
      # Activity tracking
      add :joined_at, :utc_datetime, default: fragment("NOW()")
      add :last_prediction_at, :utc_datetime
      
      timestamps()
    end

    # Track 2: Individual live predictions
    create table(:mock_draft_predictions) do
      add :participant_id, references(:mock_draft_participants, on_delete: :delete_all), null: false
      
      # Prediction details
      add :pick_number, :integer, null: false
      add :predicted_player_id, references(:players, on_delete: :delete_all), null: false
      
      # Scoring results
      add :points_awarded, :integer, default: 0
      add :prediction_type, :string # 'exact', 'general', 'round'
      add :is_locked, :boolean, default: false
      
      # Timing
      add :predicted_at, :utc_datetime, default: fragment("NOW()")
      add :scored_at, :utc_datetime
      
      timestamps()
    end

    # Scoring events for analytics
    create table(:prediction_scoring_events) do
      add :mock_draft_id, references(:mock_drafts, on_delete: :delete_all), null: false
      
      # Actual pick details
      add :pick_number, :integer, null: false
      add :actual_player_id, references(:players, on_delete: :delete_all), null: false
      
      # Prediction statistics
      add :total_predraft_predictions, :integer, default: 0
      add :correct_predraft_predictions, :integer, default: 0
      add :total_live_predictions, :integer, default: 0
      add :correct_live_predictions, :integer, default: 0
      
      add :scoring_timestamp, :utc_datetime, default: fragment("NOW()")
      
      timestamps()
    end

    # Indexes for performance
    create index(:mock_drafts, [:draft_id])
    create unique_index(:mock_drafts, [:mock_draft_token])
    
    create index(:mock_draft_submissions, [:mock_draft_id])
    create unique_index(:mock_draft_submissions, [:submission_token])
    create unique_index(:mock_draft_submissions, [:mock_draft_id, :participant_name])
    
    create index(:predicted_picks, [:submission_id])
    create index(:predicted_picks, [:pick_number])
    create unique_index(:predicted_picks, [:submission_id, :pick_number])
    
    create index(:mock_draft_participants, [:mock_draft_id])
    create unique_index(:mock_draft_participants, [:participant_token])
    create unique_index(:mock_draft_participants, [:mock_draft_id, :display_name])
    
    create index(:mock_draft_predictions, [:participant_id])
    create index(:mock_draft_predictions, [:pick_number])
    create unique_index(:mock_draft_predictions, [:participant_id, :pick_number])
    
    create index(:prediction_scoring_events, [:mock_draft_id])
    create index(:prediction_scoring_events, [:pick_number])
  end
end