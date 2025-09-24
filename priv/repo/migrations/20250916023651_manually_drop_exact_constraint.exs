defmodule AceApp.Repo.Migrations.ManuallyDropExactConstraint do
  use Ecto.Migration

  def change do
    # Check for existing picks that might conflict
    execute """
    DO $$
    DECLARE
        pick_rec RECORD;
    BEGIN
        RAISE NOTICE 'Checking for existing picks with champion_id = 1 in draft_id = 8:';
        FOR pick_rec IN
            SELECT id, draft_id, player_id, champion_id
            FROM picks 
            WHERE draft_id = 8 AND champion_id = 1
        LOOP
            RAISE NOTICE 'Pick ID: %, Draft: %, Player: %, Champion: %', 
                pick_rec.id, pick_rec.draft_id, pick_rec.player_id, pick_rec.champion_id;
        END LOOP;
        
        -- Also create and immediately drop the constraint to see if it exists
        BEGIN
            ALTER TABLE picks ADD CONSTRAINT picks_draft_champion_unique UNIQUE (draft_id, champion_id);
            RAISE NOTICE 'Successfully added constraint picks_draft_champion_unique';
            ALTER TABLE picks DROP CONSTRAINT picks_draft_champion_unique;
            RAISE NOTICE 'Successfully dropped constraint picks_draft_champion_unique';
        EXCEPTION 
            WHEN duplicate_object THEN
                RAISE NOTICE 'Constraint picks_draft_champion_unique already exists';
                ALTER TABLE picks DROP CONSTRAINT picks_draft_champion_unique;
                RAISE NOTICE 'Dropped existing constraint picks_draft_champion_unique';
            WHEN undefined_object THEN
                RAISE NOTICE 'Constraint picks_draft_champion_unique does not exist for dropping';
        END;
    END $$;
    """, "-- Diagnostic migration"
  end
end
