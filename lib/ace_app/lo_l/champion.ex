defmodule AceApp.LoL.Champion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "champions" do
    field(:name, :string)
    field(:key, :string)
    field(:title, :string)
    field(:image_url, :string)
    field(:roles, {:array, :string})
    field(:tags, {:array, :string})
    field(:difficulty, :integer)
    field(:enabled, :boolean, default: false)
    field(:release_date, :date)

    has_many(:skins, AceApp.LoL.ChampionSkin)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(champion, attrs) do
    champion
    |> cast(attrs, [
      :name,
      :key,
      :title,
      :image_url,
      :roles,
      :tags,
      :difficulty,
      :enabled,
      :release_date
    ])
    |> validate_required([
      :name,
      :key,
      :title,
      :image_url,
      :roles,
      :tags,
      :difficulty,
      :release_date
    ])
    |> unique_constraint(:key)
  end
end
