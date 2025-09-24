defmodule AceApp.Repo.Migrations.AddTimerStateToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :timer_status, :string, default: "stopped", null: false
      add :timer_remaining_seconds, :integer, default: 0, null: false
      add :timer_started_at, :utc_datetime
    end

    create index(:drafts, [:timer_status])
    create index(:drafts, [:timer_started_at])
  end
end
