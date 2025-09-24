defmodule AceApp.Repo.Migrations.CreateChampions do
  use Ecto.Migration

  def change do
    create table(:champions) do
      add :name, :string
      add :key, :string
      add :title, :string
      add :image_url, :string
      add :roles, {:array, :string}
      add :tags, {:array, :string}
      add :difficulty, :integer
      add :enabled, :boolean, default: false, null: false
      add :release_date, :date

      timestamps(type: :utc_datetime)
    end

    create unique_index(:champions, [:key])
  end
end
