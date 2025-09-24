defmodule AceApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :discord_id, :string, null: false
      add :discord_username, :string, null: false
      add :discord_discriminator, :string
      add :discord_avatar_url, :text
      add :discord_email, :string
      add :is_admin, :boolean, null: false, default: false
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:discord_id])
    create index(:users, [:is_admin])
    create index(:users, [:discord_username])
  end
end