defmodule AceApp.Repo.Migrations.CreateSpectatorControls do
  use Ecto.Migration

  def change do
    create table(:spectator_controls) do
      add :draft_id, references(:drafts, on_delete: :delete_all), null: false
      add :show_player_notes, :boolean, default: false
      add :show_detailed_stats, :boolean, default: true
      add :show_match_history, :boolean, default: false
      add :current_highlight_player_id, references(:players, on_delete: :nilify_all)
      add :stream_overlay_config, :map, default: %{}
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:spectator_controls, [:draft_id])
    create index(:spectator_controls, [:current_highlight_player_id])
  end
end