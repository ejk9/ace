defmodule AceApp.Repo.Migrations.AddChampionToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :champion_id, references(:champions, on_delete: :nilify_all), null: true
      add :preferred_skin_id, :integer, null: true
    end

    create index(:players, [:champion_id])
  end
end