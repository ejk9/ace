defmodule AceApp.Repo.Migrations.AddCaptainModeSupport do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :is_captain, :boolean, default: false, null: false
    end
    
    # Create a partial unique index to ensure only one captain per team in captain mode drafts
    # This allows multiple captains across different drafts but only one per team within a draft
    create index(:players, [:draft_id, :is_captain], 
      where: "is_captain = true", 
      name: :idx_one_captain_per_draft,
      comment: "Ensures only one captain per draft when is_captain is true"
    )
  end
end
