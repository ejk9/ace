defmodule AceApp.Repo.Migrations.AddCaptainsRequiredToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :captains_required, :boolean, default: false, null: false
    end
  end
end
