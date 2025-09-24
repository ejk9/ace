defmodule AceApp.Repo.Migrations.DropChampionUniqueConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:picks, [:draft_id, :champion_id])
  end
end
