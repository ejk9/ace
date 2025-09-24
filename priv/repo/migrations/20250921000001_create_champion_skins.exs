defmodule AceApp.Repo.Migrations.CreateChampionSkins do
  use Ecto.Migration

  def change do
    create table(:champion_skins) do
      add :champion_id, references(:champions, on_delete: :delete_all), null: false
      add :skin_id, :integer, null: false
      add :name, :string, null: false
      add :splash_url, :string, null: false
      add :loading_url, :string
      add :tile_url, :string
      add :rarity, :string  # "common", "epic", "legendary", "mythic", "ultimate"
      add :cost, :integer   # RP cost
      add :release_date, :date
      add :enabled, :boolean, default: true
      add :chromas, {:array, :map}, default: []  # Array of chroma data

      timestamps(type: :utc_datetime)
    end

    create unique_index(:champion_skins, [:champion_id, :skin_id])
    create index(:champion_skins, [:champion_id])
    create index(:champion_skins, [:enabled])
  end
end