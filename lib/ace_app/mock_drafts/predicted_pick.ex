defmodule AceApp.MockDrafts.PredictedPick do
  use Ecto.Schema
  import Ecto.Changeset

  schema "predicted_picks" do
    field :pick_number, :integer
    field :points_awarded, :integer, default: 0
    field :is_correct, :boolean, default: false
    field :prediction_type, :string

    belongs_to :submission, AceApp.MockDrafts.MockDraftSubmission
    belongs_to :team, AceApp.Drafts.Team
    belongs_to :predicted_player, AceApp.Drafts.Player
    belongs_to :actual_player, AceApp.Drafts.Player

    timestamps()
  end

  @doc false
  def changeset(predicted_pick, attrs) do
    predicted_pick
    |> cast(attrs, [
      :submission_id,
      :pick_number,
      :team_id,
      :predicted_player_id,
      :actual_player_id,
      :points_awarded,
      :is_correct,
      :prediction_type
    ])
    |> validate_required([:submission_id, :pick_number, :team_id, :predicted_player_id])
    |> unique_constraint([:submission_id, :pick_number])
    |> foreign_key_constraint(:submission_id)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:predicted_player_id)
    |> foreign_key_constraint(:actual_player_id)
    |> validate_number(:pick_number, greater_than: 0)
    |> validate_number(:points_awarded, greater_than_or_equal_to: 0)
    |> validate_inclusion(:prediction_type, ["exact", "right_player", "right_round", "role_match", "miss"])
  end
end