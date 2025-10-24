defmodule AceApp.Repo.Migrations.AddDraftVariant do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :draft_variant, :string, default: "standard", null: false
    end
  end
end
