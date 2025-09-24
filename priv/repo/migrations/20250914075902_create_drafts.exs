defmodule AceApp.Repo.Migrations.CreateDrafts do
  use Ecto.Migration

  def change do
    create table(:drafts) do
      add :name, :string, null: false
      add :status, :string, null: false, default: "setup"
      add :format, :string, null: false, default: "snake"
      add :pick_timer_seconds, :integer, null: false, default: 60
      add :current_turn_team_id, :integer
      add :current_pick_deadline, :utc_datetime
      add :organizer_token, :string, null: false
      add :spectator_token, :string, null: false
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:drafts, [:organizer_token])
    create unique_index(:drafts, [:spectator_token])
    create index(:drafts, [:status])
    create index(:drafts, [:current_turn_team_id])
  end
end