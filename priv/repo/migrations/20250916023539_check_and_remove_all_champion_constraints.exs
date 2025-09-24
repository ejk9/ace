defmodule AceApp.Repo.Migrations.CheckAndRemoveAllChampionConstraints do
  use Ecto.Migration

  def change do
    # Use raw SQL to find and drop any constraint containing 'champion' and 'unique'
    execute """
    DO $$
    DECLARE
        constraint_name TEXT;
    BEGIN
        FOR constraint_name IN
            SELECT conname 
            FROM pg_constraint 
            WHERE conrelid = 'picks'::regclass 
            AND contype = 'u'
            AND (conname LIKE '%champion%' OR conname LIKE '%draft_champion%')
        LOOP
            EXECUTE 'ALTER TABLE picks DROP CONSTRAINT ' || constraint_name;
            RAISE NOTICE 'Dropped constraint: %', constraint_name;
        END LOOP;
    END $$;
    """, "-- Irreversible constraint removal"
  end
end
