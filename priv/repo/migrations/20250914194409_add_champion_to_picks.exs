defmodule AceApp.Repo.Migrations.AddChampionToPicks do
  use Ecto.Migration

  def change do
    alter table(:picks) do
      add :champion_id, references(:champions, on_delete: :nilify_all)
    end
  end
end
