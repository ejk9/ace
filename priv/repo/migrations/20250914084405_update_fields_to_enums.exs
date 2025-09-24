defmodule AceApp.Repo.Migrations.UpdateFieldsToEnums do
  use Ecto.Migration

  def change do
    # Drop existing data first (since this is early development)
    # In production, you'd want to convert existing data
    
    execute "TRUNCATE TABLE picks CASCADE"
    execute "TRUNCATE TABLE player_accounts CASCADE" 
    execute "TRUNCATE TABLE players CASCADE"
    execute "TRUNCATE TABLE teams CASCADE"
    execute "TRUNCATE TABLE draft_events CASCADE"
    execute "TRUNCATE TABLE spectator_controls CASCADE"
    execute "TRUNCATE TABLE drafts CASCADE"
    
    # Update drafts table - status and format enums
    alter table(:drafts) do
      modify :status, :string, null: false, default: "setup"
      modify :format, :string, null: false, default: "snake"
    end
    
    # Update players table - preferred_roles as enum array
    alter table(:players) do
      modify :preferred_roles, {:array, :string}, default: []
    end
    
    # Update player_accounts table - rank and region enums
    alter table(:player_accounts) do
      modify :rank_tier, :string, null: true
      modify :rank_division, :string, null: true
      modify :server_region, :string, null: false, default: "na1"
    end
  end
  
  # Note: Ecto.Enum fields are stored as strings in the database
  # The enum validation happens at the application level
  # This migration ensures the database columns are properly typed as strings
end