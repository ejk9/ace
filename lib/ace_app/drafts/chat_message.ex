defmodule AceApp.Drafts.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_message_types [
    # Regular chat message
    "message",
    # System notifications (player joined, pick made, etc.)
    "system",
    # Admin announcements
    "announcement",
    # Emote/reaction messages
    "emote"
  ]

  @valid_sender_types [
    # Team captain
    "captain",
    # Draft organizer/admin
    "organizer",
    # Spectator with chat permissions
    "spectator",
    # Team member with chat permissions
    "team_member",
    # System-generated messages
    "system"
  ]

  schema "chat_messages" do
    field(:content, :string)
    field(:message_type, :string, default: "message")
    field(:sender_type, :string)
    field(:sender_name, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:team, AceApp.Drafts.Team)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [
      :content,
      :message_type,
      :sender_type,
      :sender_name,
      :metadata,
      :draft_id,
      :team_id
    ])
    |> validate_required([:content, :sender_type, :sender_name, :draft_id])
    |> validate_inclusion(:message_type, @valid_message_types)
    |> validate_inclusion(:sender_type, @valid_sender_types)
    |> validate_length(:content, min: 1, max: 1000)
    |> validate_length(:sender_name, min: 1, max: 50)
    |> validate_team_chat_permissions()
  end

  def valid_message_types, do: @valid_message_types
  def valid_sender_types, do: @valid_sender_types

  # Private validation functions

  defp validate_team_chat_permissions(changeset) do
    team_id = get_field(changeset, :team_id)
    sender_type = get_field(changeset, :sender_type)

    case {team_id, sender_type} do
      # System messages can't have team_id (check this first)
      {team_id, "system"} when not is_nil(team_id) ->
        add_error(changeset, :team_id, "system messages cannot be team-specific")

      # Team-specific chat requires captain, organizer, or team member
      {team_id, sender_type}
      when not is_nil(team_id) and sender_type not in ["captain", "organizer", "team_member"] ->
        add_error(
          changeset,
          :sender_type,
          "only captains, organizers, and team members can send team messages"
        )

      _ ->
        changeset
    end
  end
end
