defmodule AceApp.Repo.Migrations.AddReadyStateToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :is_ready, :boolean, default: false, null: false
    end
  end
end