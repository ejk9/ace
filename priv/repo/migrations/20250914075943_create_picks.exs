defmodule AceApp.Repo.Migrations.CreatePicks do
  use Ecto.Migration

  def change do
    create table(:picks) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :pick_number, :integer, null: false
      add :round_number, :integer, null: false
      add :picked_at, :utc_datetime, null: false
      add :pick_duration_ms, :integer
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:picks, [:draft_id, :pick_number])
    create unique_index(:picks, [:draft_id, :player_id])
    create index(:picks, [:draft_id])
    create index(:picks, [:team_id])
    create index(:picks, [:round_number])
  end
end