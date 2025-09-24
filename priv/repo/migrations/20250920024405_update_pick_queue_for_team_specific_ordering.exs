defmodule AceApp.Repo.Migrations.UpdatePickQueueForTeamSpecificOrdering do
  use Ecto.Migration

  def change do
    # Remove the unique constraint on draft_id and team_id to allow multiple picks per team
    drop unique_index(:pick_queue, [:draft_id, :team_id], where: "status = 'queued'")
    
    # Add queue_position field to track ordering within each team
    alter table(:pick_queue) do
      add :queue_position, :integer, null: false, default: 1
    end
    
    # Create new unique constraint on draft_id, team_id, and queue_position
    # This ensures each team can have multiple picks but each position is unique per team
    create unique_index(:pick_queue, [:draft_id, :team_id, :queue_position], where: "status = 'queued'")
  end
end