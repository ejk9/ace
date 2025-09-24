defmodule AceApp.Repo.Migrations.ChangeDefaultVisibilityToPrivate do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      modify :visibility, :string, default: "private", null: false
    end
  end
end