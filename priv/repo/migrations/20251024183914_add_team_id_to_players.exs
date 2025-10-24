defmodule AceApp.Repo.Migrations.AddTeamIdToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :team_id, references(:teams, on_delete: :nilify_all), null: true
    end
    
    create index(:players, [:team_id])
  end
end
