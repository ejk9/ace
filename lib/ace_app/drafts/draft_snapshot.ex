defmodule AceApp.Drafts.DraftSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "draft_snapshots" do
    field :pick_number, :integer
    field :snapshot_name, :string
    field :draft_state, :map
    field :teams_state, :map
    field :picks_state, :map
    field :created_by_user_id, :string

    belongs_to :draft, AceApp.Drafts.Draft

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(draft_snapshot, attrs) do
    draft_snapshot
    |> cast(attrs, [:draft_id, :pick_number, :snapshot_name, :draft_state, :teams_state, :picks_state, :created_by_user_id])
    |> validate_required([:draft_id, :pick_number, :draft_state, :teams_state, :picks_state])
    |> validate_number(:pick_number, greater_than_or_equal_to: 0)
    |> validate_length(:snapshot_name, max: 100)
    |> validate_length(:created_by_user_id, max: 100)
    |> unique_constraint([:draft_id, :pick_number])
  end
end