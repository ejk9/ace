defmodule AceApp.Repo.Migrations.CreatePlayerAccounts do
  use Ecto.Migration

  def change do
    create table(:player_accounts) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :summoner_name, :string, null: false
      add :rank_tier, :string
      add :rank_division, :string
      add :server_region, :string, null: false, default: "NA1"
      add :is_primary, :boolean, default: false
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_accounts, [:summoner_name, :server_region])
    create index(:player_accounts, [:player_id])
    create index(:player_accounts, [:is_primary])
    
    # Ensure each player has at least one account (enforced in application logic)
    # Ensure only one primary account per player
    create unique_index(:player_accounts, [:player_id], where: "is_primary = true", name: :player_accounts_primary_unique_index)
  end
end