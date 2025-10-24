defmodule AceApp.Drafts.Player do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias AceApp.LoL

  schema "players" do
    field(:display_name, :string)
    field(:preferred_roles, {:array, Ecto.Enum}, values: LoL.roles(), default: [])
    field(:custom_stats, :map, default: %{})
    field(:organizer_notes, :string)
    field(:preferred_skin_id, :integer)
    field(:is_captain, :boolean, default: false)

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:team, AceApp.Drafts.Team)
    belongs_to(:champion, AceApp.LoL.Champion)
    has_many(:player_accounts, AceApp.Drafts.PlayerAccount)
    has_many(:picks, AceApp.Drafts.Pick)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:display_name, :preferred_roles, :custom_stats, :organizer_notes, :draft_id, :team_id, :champion_id, :preferred_skin_id, :is_captain])
    |> validate_required([:display_name, :draft_id])
    |> validate_preferred_roles()
    |> validate_captain_uniqueness()
    |> unique_constraint([:draft_id, :display_name])
    |> foreign_key_constraint(:champion_id)
    |> foreign_key_constraint(:team_id)
  end
  
  defp validate_captain_uniqueness(changeset) do
    # Only validate if is_captain is being set to true
    if get_change(changeset, :is_captain) == true do
      draft_id = get_field(changeset, :draft_id)
      team_id = get_field(changeset, :team_id)
      player_id = get_field(changeset, :id)
      
      # Captain must be assigned to a team
      if is_nil(team_id) do
        add_error(changeset, :team_id, "captain must be assigned to a team")
      else
        # Check if another captain already exists for this team
        query = if is_nil(player_id) do
          # New record - just check if any captain exists for this team
          from p in __MODULE__,
            where: p.draft_id == ^draft_id and p.team_id == ^team_id and p.is_captain == true,
            select: count(p.id)
        else
          # Existing record - exclude this player from the check
          from p in __MODULE__,
            where: p.draft_id == ^draft_id and p.team_id == ^team_id and p.is_captain == true,
            where: p.id != ^player_id,
            select: count(p.id)
        end
        
        case AceApp.Repo.one(query) do
          0 -> changeset
          _ -> add_error(changeset, :is_captain, "only one captain allowed per team")
        end
      end
    else
      changeset
    end
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
