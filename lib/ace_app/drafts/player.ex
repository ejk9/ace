defmodule AceApp.Drafts.Player do
  use Ecto.Schema
  import Ecto.Changeset

  alias AceApp.LoL

  schema "players" do
    field(:display_name, :string)
    field(:preferred_roles, {:array, Ecto.Enum}, values: LoL.roles(), default: [])
    field(:custom_stats, :map, default: %{})
    field(:organizer_notes, :string)
    field(:preferred_skin_id, :integer)

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:champion, AceApp.LoL.Champion)
    has_many(:player_accounts, AceApp.Drafts.PlayerAccount)
    has_many(:picks, AceApp.Drafts.Pick)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:display_name, :preferred_roles, :custom_stats, :organizer_notes, :draft_id, :champion_id, :preferred_skin_id])
    |> validate_required([:display_name, :draft_id])
    |> validate_preferred_roles()
    |> unique_constraint([:draft_id, :display_name])
    |> foreign_key_constraint(:champion_id)
  end

  defp validate_preferred_roles(changeset) do
    case get_field(changeset, :preferred_roles) do
      roles when is_list(roles) ->
        if LoL.valid_roles?(roles) do
          changeset
        else
          add_error(changeset, :preferred_roles, "contains invalid roles")
        end

      _ ->
        changeset
    end
  end

  def valid_roles, do: LoL.roles()
end
