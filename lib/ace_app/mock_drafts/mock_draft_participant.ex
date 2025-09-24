defmodule AceApp.MockDrafts.MockDraftParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mock_draft_participants" do
    field :display_name, :string
    field :participant_token, :string
    field :total_score, :integer, default: 0
    field :predictions_made, :integer, default: 0
    field :accuracy_percentage, :decimal, default: Decimal.new("0.00")
    field :joined_at, :utc_datetime
    field :last_prediction_at, :utc_datetime

    belongs_to :mock_draft, AceApp.MockDrafts.MockDraft
    has_many :predictions, AceApp.MockDrafts.MockDraftPrediction, foreign_key: :participant_id

    timestamps()
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :mock_draft_id,
      :display_name,
      :participant_token,
      :total_score,
      :predictions_made,
      :accuracy_percentage,
      :joined_at,
      :last_prediction_at
    ])
    |> validate_required([:mock_draft_id, :display_name, :participant_token])
    |> unique_constraint(:participant_token)
    |> unique_constraint([:mock_draft_id, :display_name])
    |> foreign_key_constraint(:mock_draft_id)
    |> validate_length(:display_name, min: 1, max: 255)
    |> validate_number(:total_score, greater_than_or_equal_to: 0)
    |> validate_number(:predictions_made, greater_than_or_equal_to: 0)
    |> validate_number(:accuracy_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end