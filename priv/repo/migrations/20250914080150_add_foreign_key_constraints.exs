defmodule AceApp.Repo.Migrations.AddForeignKeyConstraints do
  use Ecto.Migration

  def change do
    # Add foreign key constraint from drafts to teams
    alter table(:drafts) do
      modify :current_turn_team_id, references(:teams, on_delete: :nilify_all)
    end
    
    # Index already exists from initial drafts migration
  end
end