defmodule AceApp.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :logo_url, :string
      add :captain_token, :string, null: false
      add :pick_order_position, :integer, null: false
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:teams, [:captain_token])
    create unique_index(:teams, [:draft_id, :name])
    create unique_index(:teams, [:draft_id, :pick_order_position])
    create index(:teams, [:draft_id])
  end
end