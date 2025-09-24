defmodule AceApp.LoL.ChampionSkin do
  use Ecto.Schema
  import Ecto.Changeset
  alias AceApp.LoL.Champion

  schema "champion_skins" do
    field(:skin_id, :integer)
    field(:name, :string)
    field(:splash_url, :string)
    field(:loading_url, :string)
    field(:tile_url, :string)
    field(:rarity, :string)
    field(:cost, :integer)
    field(:release_date, :date)
    field(:enabled, :boolean, default: true)
    field(:chromas, {:array, :map}, default: [])

    belongs_to(:champion, Champion)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(skin, attrs) do
    skin
    |> cast(attrs, [
      :champion_id,
      :skin_id,
      :name,
      :splash_url,
      :loading_url,
      :tile_url,
      :rarity,
      :cost,
      :release_date,
      :enabled,
      :chromas
    ])
    |> validate_required([
      :champion_id,
      :skin_id,
      :name,
      :splash_url
    ])
    |> validate_inclusion(:rarity, ["common", "epic", "legendary", "mythic", "ultimate"])
    |> unique_constraint([:champion_id, :skin_id])
    |> foreign_key_constraint(:champion_id)
  end

  @doc """
  Returns the default skin (skin_id: 0) for a champion
  """
  def default_skin_changeset(champion, attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(Map.merge(%{
      champion_id: champion.id,
      skin_id: 0,
      name: champion.name,
      splash_url: champion.image_url,
      rarity: "common",
      enabled: true
    }, attrs))
  end
end