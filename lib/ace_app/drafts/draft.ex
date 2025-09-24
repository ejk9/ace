defmodule AceApp.Drafts.Draft do
  use Ecto.Schema
  import Ecto.Changeset

  schema "drafts" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:setup, :active, :paused, :completed], default: :setup)
    field(:format, Ecto.Enum, values: [:snake, :regular, :auction], default: :snake)
    field(:pick_timer_seconds, :integer, default: 60)
    field(:current_pick_deadline, :utc_datetime)
    field(:organizer_token, :string)
    field(:spectator_token, :string)
    
    # Timer state fields
    field(:timer_status, :string, default: "stopped")
    field(:timer_remaining_seconds, :integer, default: 0)
    field(:timer_started_at, :utc_datetime)
    
    # Discord integration fields
    field(:discord_webhook_url, :string)
    field(:discord_webhook_validated, :boolean, default: false)
    field(:discord_notifications_enabled, :boolean, default: true)
    
    # Visibility and access control fields
    field(:visibility, Ecto.Enum, values: [:public, :private], default: :private)
    field(:is_featured, :boolean, default: false)

    belongs_to(:current_turn_team, AceApp.Drafts.Team, foreign_key: :current_turn_team_id)
    belongs_to(:user, AceApp.Auth.User)
    has_many(:teams, AceApp.Drafts.Team)
    has_many(:players, AceApp.Drafts.Player)
    has_many(:picks, AceApp.Drafts.Pick)
    has_many(:draft_events, AceApp.Drafts.DraftEvent)
    has_one(:spectator_controls, AceApp.Drafts.SpectatorControls)
    has_one(:mock_draft, AceApp.MockDrafts.MockDraft)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :name,
      :status,
      :format,
      :pick_timer_seconds,
      :current_turn_team_id,
      :current_pick_deadline,
      :organizer_token,
      :spectator_token,
      :timer_status,
      :timer_remaining_seconds,
      :timer_started_at,
      :discord_webhook_url,
      :discord_webhook_validated,
      :discord_notifications_enabled,
      :user_id,
      :visibility,
      :is_featured
    ])
    |> validate_required([:name, :format])
    |> validate_length(:name, min: 1)
    |> validate_inclusion(:format, [:snake, :regular, :auction])
    |> validate_number(:pick_timer_seconds,
      greater_than_or_equal_to: 10,
      less_than_or_equal_to: 300
    )
    |> maybe_generate_tokens()
    |> validate_required([:organizer_token, :spectator_token])
    |> unique_constraint(:organizer_token)
    |> unique_constraint(:spectator_token)
  end

  defp maybe_generate_tokens(%Ecto.Changeset{} = changeset) do
    changeset
    |> maybe_put_change(:organizer_token, fn -> generate_token("org") end)
    |> maybe_put_change(:spectator_token, fn -> generate_token("spec") end)
  end

  defp maybe_put_change(%Ecto.Changeset{} = changeset, field, generator) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, generator.())
    end
  end

  defp generate_token(prefix) do
    # Generate exactly 32 characters total
    prefix_with_underscore = "#{prefix}_"
    suffix_length = 32 - String.length(prefix_with_underscore)

    suffix =
      :crypto.strong_rand_bytes(24)
      |> Base.url_encode64(padding: false)
      |> String.slice(0, suffix_length)

    "#{prefix_with_underscore}#{suffix}"
  end
end
