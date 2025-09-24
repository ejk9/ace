defmodule AceApp.Drafts.SpectatorControls do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spectator_controls" do
    field(:show_player_notes, :boolean, default: false)
    field(:show_detailed_stats, :boolean, default: true)
    field(:show_match_history, :boolean, default: false)
    field(:stream_overlay_config, :map, default: %{})

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:current_highlight_player, AceApp.Drafts.Player)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(spectator_controls, attrs) do
    spectator_controls
    |> cast(attrs, [
      :show_player_notes,
      :show_detailed_stats,
      :show_match_history,
      :stream_overlay_config,
      :draft_id,
      :current_highlight_player_id
    ])
    |> validate_required([:draft_id])
    |> unique_constraint(:draft_id)
  end
end
