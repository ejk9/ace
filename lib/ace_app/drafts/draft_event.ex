defmodule AceApp.Drafts.DraftEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_event_types [
    "draft_created",
    "draft_started",
    "draft_paused",
    "draft_resumed",
    "draft_completed",
    "team_added",
    "player_added",
    "pick_made",
    "turn_timeout",
    "manual_override"
  ]

  schema "draft_events" do
    field(:event_type, :string)
    field(:event_data, :map, default: %{})

    belongs_to(:draft, AceApp.Drafts.Draft)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(draft_event, attrs) do
    draft_event
    |> cast(attrs, [:event_type, :event_data, :draft_id])
    |> validate_required([:event_type, :draft_id])
    |> validate_inclusion(:event_type, @valid_event_types)
  end

  def valid_event_types, do: @valid_event_types
end
