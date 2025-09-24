defmodule AceApp.Repo.Migrations.ListAllPicksConstraints do
  use Ecto.Migration

  def change do
    # List all constraints on picks table for debugging
    execute """
    DO $$
    DECLARE
        constraint_rec RECORD;
    BEGIN
        RAISE NOTICE 'All constraints on picks table:';
        FOR constraint_rec IN
            SELECT conname, contype, 
                   CASE contype
                       WHEN 'u' THEN 'UNIQUE'
                       WHEN 'f' THEN 'FOREIGN KEY'
                       WHEN 'p' THEN 'PRIMARY KEY'
                       WHEN 'c' THEN 'CHECK'
                       ELSE contype::text
                   END as constraint_type
            FROM pg_constraint 
            WHERE conrelid = 'picks'::regclass
        LOOP
            RAISE NOTICE 'Constraint: % (Type: %)', constraint_rec.conname, constraint_rec.constraint_type;
        END LOOP;
    END $$;
    """, "-- Just for debugging"
  end
end
