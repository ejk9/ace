defmodule AceApp.Repo.Migrations.RemovePicksDraftChampionUniqueConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists constraint(:picks, "picks_draft_champion_unique")
  end
end
