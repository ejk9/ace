defmodule AceApp.Repo.Migrations.RemoveActualChampionUniqueConstraint do
  use Ecto.Migration

  def change do
    # Drop the unique constraint that was named picks_draft_champion_unique
    execute "ALTER TABLE picks DROP CONSTRAINT IF EXISTS picks_draft_champion_unique;", 
            "-- This is irreversible, constraint would need to be recreated manually"
    
    # Also try dropping any unique index on champion_id
    drop_if_exists unique_index(:picks, [:draft_id, :champion_id], name: :picks_draft_champion_unique)
  end
end
