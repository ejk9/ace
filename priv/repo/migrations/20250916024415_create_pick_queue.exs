defmodule AceApp.Repo.Migrations.CreatePickQueue do
  use Ecto.Migration

  def change do
    create table(:pick_queue) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :champion_id, references(:champions, on_delete: :nilify_all)
      add :status, :string, default: "queued", null: false
      add :queued_at, :utc_datetime, null: false
      add :queued_by_token, :string, null: false  # captain or team member token
      
      timestamps(type: :utc_datetime)
    end

    create index(:pick_queue, [:draft_id])
    create index(:pick_queue, [:team_id])
    create index(:pick_queue, [:status])
    create unique_index(:pick_queue, [:draft_id, :team_id], where: "status = 'queued'")
  end
end
