defmodule AceApp.Drafts.PlayerAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias AceApp.LoL

  schema "player_accounts" do
    field(:summoner_name, :string)
    field(:rank_tier, Ecto.Enum, values: LoL.tiers())
    field(:rank_division, Ecto.Enum, values: LoL.divisions())
    field(:server_region, Ecto.Enum, values: LoL.regions(), default: :na1)
    field(:is_primary, :boolean, default: false)

    belongs_to(:player, AceApp.Drafts.Player)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player_account, attrs) do
    player_account
    |> cast(attrs, [
      :summoner_name,
      :rank_tier,
      :rank_division,
      :server_region,
      :is_primary,
      :player_id
    ])
    |> validate_required([:summoner_name, :server_region, :player_id])
    |> validate_rank_consistency()
    |> unique_constraint([:summoner_name, :server_region])
    |> unique_constraint(:player_id,
      name: :player_accounts_primary_unique_index,
      message: "can only have one primary account"
    )
  end

  defp validate_rank_consistency(changeset) do
    tier = get_field(changeset, :rank_tier)
    division = get_field(changeset, :rank_division)

    cond do
      is_nil(tier) ->
        changeset

      LoL.tier_has_divisions?(tier) and is_nil(division) ->
        add_error(changeset, :rank_division, "is required for #{LoL.tier_display_name(tier)}")

      not LoL.tier_has_divisions?(tier) and not is_nil(division) ->
        add_error(changeset, :rank_division, "is not used for #{LoL.tier_display_name(tier)}")

      true ->
        changeset
    end
  end

  def valid_tiers, do: LoL.tiers()
  def valid_divisions, do: LoL.divisions()
  def valid_regions, do: LoL.regions()

  @doc "Format the rank for display"
  def format_rank(%__MODULE__{rank_tier: tier, rank_division: division}) do
    LoL.format_rank(tier, division)
  end

  def format_rank(_), do: "Unranked"
end
