defmodule AceApp.Repo.Migrations.AddPredictionPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Indexes for MockDraftPrediction table (avoid duplicates)
    create_if_not_exists index(:mock_draft_predictions, [:participant_id, :pick_number])
    
    # Indexes for MockDraftParticipant table  
    create_if_not_exists index(:mock_draft_participants, [:mock_draft_id, :total_score])
    
    # Indexes for PredictedPick table
    create_if_not_exists index(:predicted_picks, [:submission_id])
    
    # Additional performance indexes for core tables
    create_if_not_exists index(:picks, [:draft_id, :pick_number])
    create_if_not_exists index(:players, [:draft_id, :display_name])
    create_if_not_exists index(:teams, [:draft_id, :pick_order_position])
  end
end