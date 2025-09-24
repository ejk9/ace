defmodule AceApp.Repo.Migrations.ForceDropAnyChampionConstraint do
  use Ecto.Migration

  def change do
    # Force drop any constraint with 'champion' in the name
    execute """
    DO $$
    DECLARE
        constraint_rec RECORD;
    BEGIN
        RAISE NOTICE 'Looking for any constraints with champion in the name...';
        FOR constraint_rec IN
            SELECT conname, contype
            FROM pg_constraint 
            WHERE conrelid = 'picks'::regclass
            AND conname ILIKE '%champion%'
        LOOP
            RAISE NOTICE 'Found constraint: % (type: %)', constraint_rec.conname, constraint_rec.contype;
            EXECUTE 'ALTER TABLE picks DROP CONSTRAINT ' || constraint_rec.conname;
            RAISE NOTICE 'Dropped constraint: %', constraint_rec.conname;
        END LOOP;
        
        -- Also drop any index with champion in the name
        FOR constraint_rec IN
            SELECT indexname
            FROM pg_indexes
            WHERE tablename = 'picks'
            AND indexname ILIKE '%champion%'
        LOOP
            RAISE NOTICE 'Found index: %', constraint_rec.indexname;
            EXECUTE 'DROP INDEX IF EXISTS ' || constraint_rec.indexname;
            RAISE NOTICE 'Dropped index: %', constraint_rec.indexname;
        END LOOP;
    END $$;
    """, "-- Force cleanup"
  end
end
