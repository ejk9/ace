defmodule AceApp.Repo.Migrations.CreateDraftSnapshotsAndAuditLog do
  use Ecto.Migration

  def change do
    # Draft snapshots for rollback functionality
    create table(:draft_snapshots) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :pick_number, :integer, null: false
      add :snapshot_name, :string, size: 100
      add :draft_state, :map, null: false
      add :teams_state, :map, null: false
      add :picks_state, :map, null: false
      add :created_by_user_id, :string, size: 100
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:draft_snapshots, [:draft_id])
    create unique_index(:draft_snapshots, [:draft_id, :pick_number])

    # Enhanced audit logging for all draft operations
    create table(:draft_audit_log) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :action_type, :string, size: 50, null: false
      add :action_data, :map, null: false
      add :performed_by, :string, size: 100
      add :performed_by_role, :string, size: 20
      add :client_info, :map
      
      timestamps(type: :utc_datetime, updated_at: false)
    end
    
    create index(:draft_audit_log, [:draft_id])
    create index(:draft_audit_log, [:draft_id, :action_type])
    create index(:draft_audit_log, [:draft_id, :inserted_at])
  end
end