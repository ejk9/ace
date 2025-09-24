defmodule AceApp.Drafts.PickQueue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pick_queue" do
    field(:status, :string, default: "queued")
    field(:queued_at, :utc_datetime)
    field(:queued_by_token, :string)
    field(:queue_position, :integer, default: 1)

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:team, AceApp.Drafts.Team)
    belongs_to(:player, AceApp.Drafts.Player)
    belongs_to(:champion, AceApp.LoL.Champion)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pick_queue, attrs) do
    pick_queue
    |> cast(attrs, [
      :draft_id,
      :team_id,
      :player_id,
      :champion_id,
      :status,
      :queued_at,
      :queued_by_token,
      :queue_position
    ])
    |> validate_required([:draft_id, :team_id, :player_id, :queued_at, :queued_by_token, :queue_position])
    |> validate_inclusion(:status, ["queued", "executed", "cancelled"])
    |> validate_number(:queue_position, greater_than: 0)
    |> unique_constraint([:draft_id, :team_id, :queue_position],
      name: :pick_queue_draft_id_team_id_queue_position_index,
      message: "queue position already taken for this team"
    )
  end
end
