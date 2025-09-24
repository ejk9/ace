defmodule AceApp.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :display_name, :string, null: false
      add :preferred_roles, {:array, :string}, default: []
      add :custom_stats, :map, default: %{}
      add :organizer_notes, :text
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:players, [:draft_id, :display_name])
    create index(:players, [:draft_id])
    create index(:players, [:preferred_roles], using: :gin)
  end
end