defmodule AceApp.Drafts.Pick do
  use Ecto.Schema
  import Ecto.Changeset

  schema "picks" do
    field(:pick_number, :integer)
    field(:round_number, :integer)
    field(:picked_at, :utc_datetime)
    field(:pick_duration_ms, :integer)

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:team, AceApp.Drafts.Team)
    belongs_to(:player, AceApp.Drafts.Player)
    belongs_to(:champion, AceApp.LoL.Champion)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pick, attrs) do
    pick
    |> cast(attrs, [
      :pick_number,
      :round_number,
      :picked_at,
      :pick_duration_ms,
      :draft_id,
      :team_id,
      :player_id,
      :champion_id
    ])
    |> validate_required([
      :pick_number,
      :round_number,
      :picked_at,
      :draft_id,
      :team_id,
      :player_id,
      :champion_id
    ])
    |> validate_number(:pick_number, greater_than: 0)
    |> validate_number(:round_number, greater_than: 0)
    |> validate_number(:pick_duration_ms, greater_than_or_equal_to: 0)
    |> unique_constraint([:draft_id, :pick_number])
    |> unique_constraint([:draft_id, :player_id], message: "player already drafted")
  end
end
