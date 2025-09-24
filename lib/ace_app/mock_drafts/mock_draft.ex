defmodule AceApp.MockDrafts.MockDraft do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mock_drafts" do
    field :predraft_enabled, :boolean, default: true
    field :live_enabled, :boolean, default: true
    field :mock_draft_token, :string
    field :submission_deadline, :utc_datetime
    field :max_predraft_participants, :integer, default: 100
    field :max_live_participants, :integer, default: 100
    field :scoring_rules, :map, default: %{}
    field :is_enabled, :boolean, default: true

    belongs_to :draft, AceApp.Drafts.Draft
    has_many :submissions, AceApp.MockDrafts.MockDraftSubmission
    has_many :participants, AceApp.MockDrafts.MockDraftParticipant
    has_many :scoring_events, AceApp.MockDrafts.PredictionScoringEvent

    timestamps()
  end

  @doc false
  def changeset(mock_draft, attrs) do
    mock_draft
    |> cast(attrs, [
      :draft_id,
      :predraft_enabled,
      :live_enabled,
      :mock_draft_token,
      :submission_deadline,
      :max_predraft_participants,
      :max_live_participants,
      :scoring_rules,
      :is_enabled
    ])
    |> validate_required([:draft_id, :mock_draft_token])
    |> unique_constraint(:mock_draft_token)
    |> foreign_key_constraint(:draft_id)
    |> validate_number(:max_predraft_participants, greater_than: 0)
    |> validate_number(:max_live_participants, greater_than: 0)
    |> validate_at_least_one_track_enabled()
  end

  defp validate_at_least_one_track_enabled(changeset) do
    predraft_enabled = get_field(changeset, :predraft_enabled)
    live_enabled = get_field(changeset, :live_enabled)

    if predraft_enabled || live_enabled do
      changeset
    else
      add_error(changeset, :predraft_enabled, "at least one track must be enabled")
    end
  end
end