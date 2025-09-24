defmodule AceApp.MockDrafts.MockDraftSubmission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mock_draft_submissions" do
    field :participant_name, :string
    field :submission_token, :string
    field :is_submitted, :boolean, default: false
    field :submitted_at, :utc_datetime
    field :total_accuracy_score, :integer, default: 0
    field :pick_accuracy_score, :integer, default: 0
    field :team_accuracy_score, :integer, default: 0
    field :overall_accuracy_percentage, :decimal, default: Decimal.new("0.00")

    belongs_to :mock_draft, AceApp.MockDrafts.MockDraft
    has_many :predicted_picks, AceApp.MockDrafts.PredictedPick, foreign_key: :submission_id

    timestamps()
  end

  @doc false
  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [
      :mock_draft_id,
      :participant_name,
      :submission_token,
      :is_submitted,
      :submitted_at,
      :total_accuracy_score,
      :pick_accuracy_score,
      :team_accuracy_score,
      :overall_accuracy_percentage
    ])
    |> validate_required([:mock_draft_id, :participant_name, :submission_token])
    |> unique_constraint(:submission_token)
    |> unique_constraint([:mock_draft_id, :participant_name], name: :mock_draft_submissions_mock_draft_id_participant_name_index)
    |> foreign_key_constraint(:mock_draft_id)
    |> validate_length(:participant_name, min: 1, max: 255)
    |> validate_number(:total_accuracy_score, greater_than_or_equal_to: 0)
    |> validate_number(:overall_accuracy_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end