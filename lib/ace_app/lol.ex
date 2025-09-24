defmodule AceApp.LoL do
  @moduledoc """
  League of Legends game data constants and helpers.

  This module centralizes all LoL-specific data like roles, ranks, regions, etc.
  Using atoms for better type safety and pattern matching.
  """

  @roles [:top, :jungle, :mid, :adc, :support]

  @tiers [
    :iron,
    :bronze,
    :silver,
    :gold,
    :platinum,
    :emerald,
    :diamond,
    :master,
    :grandmaster,
    :challenger
  ]

  @divisions [:i, :ii, :iii, :iv]

  @regions [
    :na1,
    :euw1,
    :eun1,
    :kr,
    :br1,
    :la1,
    :la2,
    :oc1,
    :ru,
    :tr1,
    :jp1,
    :ph2,
    :sg2,
    :th2,
    :tw2,
    :vn2
  ]

  @doc "Get all valid League of Legends roles"
  def roles, do: @roles

  @doc "Get all valid rank tiers"
  def tiers, do: @tiers

  @doc "Get all valid rank divisions"
  def divisions, do: @divisions

  @doc "Get all valid server regions"
  def regions, do: @regions

  @doc "Convert role atom to human-readable string"
  def role_display_name(:top), do: "Top"
  def role_display_name(:jungle), do: "Jungle"
  def role_display_name(:mid), do: "Mid"
  def role_display_name(:adc), do: "ADC"
  def role_display_name(:support), do: "Support"

  @doc "Convert tier atom to human-readable string"
  def tier_display_name(:iron), do: "Iron"
  def tier_display_name(:bronze), do: "Bronze"
  def tier_display_name(:silver), do: "Silver"
  def tier_display_name(:gold), do: "Gold"
  def tier_display_name(:platinum), do: "Platinum"
  def tier_display_name(:emerald), do: "Emerald"
  def tier_display_name(:diamond), do: "Diamond"
  def tier_display_name(:master), do: "Master"
  def tier_display_name(:grandmaster), do: "Grandmaster"
  def tier_display_name(:challenger), do: "Challenger"

  @doc "Convert division atom to human-readable string"
  def division_display_name(:i), do: "I"
  def division_display_name(:ii), do: "II"
  def division_display_name(:iii), do: "III"
  def division_display_name(:iv), do: "IV"

  @doc "Convert region atom to human-readable string"
  def region_display_name(:na1), do: "North America"
  def region_display_name(:euw1), do: "Europe West"
  def region_display_name(:eun1), do: "Europe Nordic & East"
  def region_display_name(:kr), do: "Korea"
  def region_display_name(:br1), do: "Brazil"
  def region_display_name(:la1), do: "Latin America North"
  def region_display_name(:la2), do: "Latin America South"
  def region_display_name(:oc1), do: "Oceania"
  def region_display_name(:ru), do: "Russia"
  def region_display_name(:tr1), do: "Turkey"
  def region_display_name(:jp1), do: "Japan"
  def region_display_name(:ph2), do: "Philippines"
  def region_display_name(:sg2), do: "Singapore"
  def region_display_name(:th2), do: "Thailand"
  def region_display_name(:tw2), do: "Taiwan"
  def region_display_name(:vn2), do: "Vietnam"

  @doc "Format a full rank display (e.g. 'Diamond II')"
  def format_rank(tier, division) when tier in @tiers and division in @divisions do
    "#{tier_display_name(tier)} #{division_display_name(division)}"
  end

  def format_rank(tier, _division) when tier in [:master, :grandmaster, :challenger] do
    # These tiers don't have divisions
    tier_display_name(tier)
  end

  def format_rank(_tier, _division), do: "Unranked"

  @doc "Check if a tier has divisions"
  def tier_has_divisions?(tier) when tier in [:master, :grandmaster, :challenger], do: false
  def tier_has_divisions?(tier) when tier in @tiers, do: true
  def tier_has_divisions?(_), do: false

  @doc "Get roles suitable for selection UI"
  def roles_for_select do
    Enum.map(@roles, &{role_display_name(&1), &1})
  end

  @doc "Get tiers suitable for selection UI"
  def tiers_for_select do
    Enum.map(@tiers, &{tier_display_name(&1), &1})
  end

  @doc "Get divisions suitable for selection UI"
  def divisions_for_select do
    Enum.map(@divisions, &{division_display_name(&1), &1})
  end

  @doc "Get regions suitable for selection UI"
  def regions_for_select do
    Enum.map(@regions, &{region_display_name(&1), &1})
  end

  @doc "Validate if roles list contains only valid roles"
  def valid_roles?(roles) when is_list(roles) do
    Enum.all?(roles, &(&1 in @roles))
  end

  def valid_roles?(_), do: false

  ## Champion database functions

  import Ecto.Query
  alias AceApp.Repo
  alias AceApp.LoL.{Champion, ChampionSkin}

  @doc "Get all champions"
  def list_champions do
    Champion
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc "Get all enabled champions"
  def list_enabled_champions do
    Champion
    |> where([c], c.enabled == true)
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc "Get champions by role"
  def list_champions_by_role(role) when role in @roles do
    Champion
    |> where([c], c.enabled == true)
    |> where([c], ^to_string(role) in c.roles)
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc "Search champions by name or title"
  def search_champions(search_term) when is_binary(search_term) do
    search_pattern = "%#{String.downcase(search_term)}%"

    Champion
    |> where([c], c.enabled == true)
    |> where(
      [c],
      fragment("LOWER(?) LIKE ?", c.name, ^search_pattern) or
        fragment("LOWER(?) LIKE ?", c.title, ^search_pattern)
    )
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc "Get a champion by ID"
  def get_champion!(id) do
    Repo.get!(Champion, id)
  end

  @doc "Get a champion by name"
  def get_champion_by_name(name) when is_binary(name) do
    Repo.get_by(Champion, name: name)
  end

  @doc "Create a champion"
  def create_champion(attrs \\ %{}) do
    %Champion{}
    |> Champion.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update a champion"
  def update_champion(%Champion{} = champion, attrs) do
    champion
    |> Champion.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a champion"
  def delete_champion(%Champion{} = champion) do
    Repo.delete(champion)
  end

  @doc "Enable/disable a champion"
  def toggle_champion_enabled(%Champion{} = champion) do
    update_champion(champion, %{enabled: !champion.enabled})
  end

  @doc "Get champions count by role"
  def get_champions_count_by_role do
    enabled_champions = list_enabled_champions()

    @roles
    |> Enum.map(fn role ->
      count =
        Enum.count(enabled_champions, fn champion ->
          to_string(role) in champion.roles
        end)

      {role, count}
    end)
    |> Enum.into(%{})
  end

  @doc "Get champion statistics"
  def get_champion_stats do
    total = from(c in Champion, select: count()) |> Repo.one()
    enabled = from(c in Champion, where: c.enabled == true, select: count()) |> Repo.one()

    %{
      total: total,
      enabled: enabled,
      disabled: total - enabled,
      by_role: get_champions_count_by_role()
    }
  end

  ## Champion Skin database functions

  @doc "Get all skins for a champion"
  def list_champion_skins(champion_id) do
    ChampionSkin
    |> where([s], s.champion_id == ^champion_id)
    |> where([s], s.enabled == true)
    |> order_by([s], s.skin_id)
    |> Repo.all()
  end

  @doc "Get a champion with all its skins"
  def get_champion_with_skins!(champion_id) do
    Champion
    |> where([c], c.id == ^champion_id)
    |> preload([c], :skins)
    |> Repo.one!()
  end

  @doc "Get a specific skin"
  def get_champion_skin!(skin_id) do
    Repo.get!(ChampionSkin, skin_id)
  end

  @doc "Get a specific skin by champion and skin_id"
  def get_champion_skin_by_ids(champion_id, skin_id) do
    ChampionSkin
    |> where([s], s.champion_id == ^champion_id and s.skin_id == ^skin_id)
    |> Repo.one()
  end

  @doc "Get default skin (skin_id: 0) for a champion"
  def get_default_skin(champion_id) do
    get_champion_skin_by_ids(champion_id, 0)
  end

  @doc "Create a champion skin"
  def create_champion_skin(attrs \\ %{}) do
    %ChampionSkin{}
    |> ChampionSkin.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update a champion skin"
  def update_champion_skin(%ChampionSkin{} = skin, attrs) do
    skin
    |> ChampionSkin.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a champion skin"
  def delete_champion_skin(%ChampionSkin{} = skin) do
    Repo.delete(skin)
  end

  @doc "Get skin statistics"
  def get_skin_stats do
    total_skins = from(s in ChampionSkin, select: count()) |> Repo.one()
    enabled_skins = from(s in ChampionSkin, where: s.enabled == true, select: count()) |> Repo.one()
    
    champions_with_skins = 
      from(s in ChampionSkin, 
        group_by: s.champion_id, 
        select: count(s.champion_id)
      ) |> Repo.all() |> length()

    %{
      total_skins: total_skins,
      enabled_skins: enabled_skins,
      champions_with_skins: champions_with_skins,
      average_skins_per_champion: if(champions_with_skins > 0, do: total_skins / champions_with_skins, else: 0)
    }
  end

  @doc "Get random champion skin for popup display"
  def get_random_champion_skin(champion_id) do
    skins = list_champion_skins(champion_id)
    case skins do
      [] -> get_default_skin(champion_id)
      [skin] -> skin
      multiple_skins -> Enum.random(multiple_skins)
    end
  end

  @doc "Get specific champion skin by skin_id"
  def get_champion_skin(champion_id, skin_id) do
    ChampionSkin
    |> where([s], s.champion_id == ^champion_id and s.skin_id == ^skin_id)
    |> Repo.one()
  end

  @doc """
  Generate correct splash URL for a champion skin.
  Uses the skin offset (skin_id mod 1000) with the champion key for Community Dragon API.
  Falls back to champion base image if no skin provided.
  """
  def get_skin_splash_url(champion, skin \\ nil)

  def get_skin_splash_url(champion, nil) do
    # No skin provided, use champion base image
    champion.image_url
  end

  def get_skin_splash_url(champion, skin) do
    # Calculate skin offset: skin_id mod 1000 gives us the Community Dragon skin offset
    skin_offset = rem(skin.skin_id, 1000)
    "https://cdn.communitydragon.org/latest/champion/#{champion.key}/splash-art/centered/skin/#{skin_offset}"
  end

  @doc """
  Get random champion skin with properly generated splash URL.
  Returns a map with skin data and correct splash_url.
  """
  def get_random_champion_skin_with_url(champion) do
    skin = get_random_champion_skin(champion.id)
    splash_url = get_skin_splash_url(champion, skin)
    
    %{
      skin: skin,
      splash_url: splash_url,
      skin_name: if(skin && skin.skin_id != 0, do: skin.name, else: nil)
    }
  end
end
