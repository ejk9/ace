defmodule AceApp.Repo.Migrations.AddUniqueDraftIdToMockDrafts do
  use Ecto.Migration

  def change do
    # Remove duplicate mock drafts, keeping only the first one for each draft_id
    execute """
    DELETE FROM mock_drafts
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM mock_drafts
      GROUP BY draft_id
    )
    """, ""
    
    # Now create the unique index
    create unique_index(:mock_drafts, [:draft_id], name: :mock_drafts_unique_draft_id_index)
  end
end