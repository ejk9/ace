defmodule AceApp.Repo.Migrations.RestoreChampionForeignKey do
  use Ecto.Migration

  def change do
    # Restore the foreign key constraint for champion_id
    alter table(:picks) do
      modify :champion_id, references(:champions, on_delete: :nilify_all)
    end
    
    # Restore the index on champion_id
    create index(:picks, [:champion_id])
  end
end
