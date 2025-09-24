defmodule AceApp.Repo.Migrations.AddTeamMemberTokenToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :team_member_token, :string, null: true
    end

    # Update existing teams with team member tokens
    execute "UPDATE teams SET team_member_token = 'mem_' || substr(md5(random()::text), 1, 28) WHERE team_member_token IS NULL"

    # Now make the column not null
    alter table(:teams) do
      modify :team_member_token, :string, null: false
    end

    create unique_index(:teams, [:team_member_token])
  end
end
