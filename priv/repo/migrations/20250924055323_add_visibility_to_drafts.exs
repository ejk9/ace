defmodule AceApp.Repo.Migrations.AddVisibilityToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :visibility, :string, default: "public", null: false
      add :is_featured, :boolean, default: false, null: false
    end

    create index(:drafts, [:visibility])
    create index(:drafts, [:is_featured])
    create index(:drafts, [:user_id, :visibility])
  end
end