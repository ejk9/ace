defmodule AceApp.Drafts.DraftAuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "draft_audit_log" do
    field :action_type, :string
    field :action_data, :map
    field :performed_by, :string
    field :performed_by_role, :string
    field :client_info, :map

    belongs_to :draft, AceApp.Drafts.Draft

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:draft_id, :action_type, :action_data, :performed_by, :performed_by_role, :client_info])
    |> validate_required([:draft_id, :action_type, :action_data])
    |> validate_length(:action_type, max: 50)
    |> validate_length(:performed_by, max: 100)
    |> validate_length(:performed_by_role, max: 20)
    |> validate_inclusion(:action_type, [
      "pick_made", "pick_modified", "pick_rollback", "emergency_pick", 
      "draft_started", "draft_paused", "draft_resumed", "draft_reset",
      "team_order_changed", "team_substituted", "player_added", "player_removed"
    ])
    |> validate_inclusion(:performed_by_role, ["organizer", "captain", "system"])
  end
end