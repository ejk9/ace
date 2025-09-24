defmodule AceApp.MockDrafts.MockDraftPrediction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mock_draft_predictions" do
    field :pick_number, :integer
    field :points_awarded, :integer, default: 0
    field :prediction_type, :string
    field :is_locked, :boolean, default: false
    field :predicted_at, :utc_datetime
    field :scored_at, :utc_datetime

    belongs_to :participant, AceApp.MockDrafts.MockDraftParticipant
    belongs_to :predicted_player, AceApp.Drafts.Player

    timestamps()
  end

  @doc false
  def changeset(prediction, attrs) do
    prediction
    |> cast(attrs, [
      :participant_id,
      :pick_number,
      :predicted_player_id,
      :points_awarded,
      :prediction_type,
      :is_locked,
      :predicted_at,
      :scored_at
    ])
    |> validate_required([:participant_id, :pick_number, :predicted_player_id])
    |> unique_constraint([:participant_id, :pick_number])
    |> foreign_key_constraint(:participant_id)
    |> foreign_key_constraint(:predicted_player_id)
    |> validate_number(:pick_number, greater_than: 0)
    |> validate_number(:points_awarded, greater_than_or_equal_to: 0)
    |> validate_inclusion(:prediction_type, ["exact", "general", "round", "miss"])
  end
end