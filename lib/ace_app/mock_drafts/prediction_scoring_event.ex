defmodule AceApp.MockDrafts.PredictionScoringEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "prediction_scoring_events" do
    field :pick_number, :integer
    field :total_predraft_predictions, :integer, default: 0
    field :correct_predraft_predictions, :integer, default: 0
    field :total_live_predictions, :integer, default: 0
    field :correct_live_predictions, :integer, default: 0
    field :scoring_timestamp, :utc_datetime

    belongs_to :mock_draft, AceApp.MockDrafts.MockDraft
    belongs_to :actual_player, AceApp.Drafts.Player

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :mock_draft_id,
      :pick_number,
      :actual_player_id,
      :total_predraft_predictions,
      :correct_predraft_predictions,
      :total_live_predictions,
      :correct_live_predictions,
      :scoring_timestamp
    ])
    |> validate_required([:mock_draft_id, :pick_number, :actual_player_id])
    |> foreign_key_constraint(:mock_draft_id)
    |> foreign_key_constraint(:actual_player_id)
    |> validate_number(:pick_number, greater_than: 0)
    |> validate_number(:total_predraft_predictions, greater_than_or_equal_to: 0)
    |> validate_number(:correct_predraft_predictions, greater_than_or_equal_to: 0)
    |> validate_number(:total_live_predictions, greater_than_or_equal_to: 0)
    |> validate_number(:correct_live_predictions, greater_than_or_equal_to: 0)
  end
end