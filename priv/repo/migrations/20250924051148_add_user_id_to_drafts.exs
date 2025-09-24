defmodule AceApp.Repo.Migrations.AddUserIdToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:drafts, [:user_id])
    create index(:drafts, [:user_id, :status])
  end
end