defmodule AceApp.Repo.Migrations.CreateDraftEvents do
  use Ecto.Migration

  def change do
    create table(:draft_events) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :event_data, :map, default: %{}
      
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:draft_events, [:draft_id])
    create index(:draft_events, [:event_type])
    create index(:draft_events, [:inserted_at])
  end
end