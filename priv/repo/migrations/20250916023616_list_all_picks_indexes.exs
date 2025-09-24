defmodule AceApp.Repo.Migrations.ListAllPicksIndexes do
  use Ecto.Migration

  def change do
    # List all indexes on picks table for debugging
    execute """
    DO $$
    DECLARE
        index_rec RECORD;
    BEGIN
        RAISE NOTICE 'All indexes on picks table:';
        FOR index_rec IN
            SELECT pi.indexname, 
                   CASE WHEN pgi.indisunique THEN 'UNIQUE' ELSE 'REGULAR' END as index_type
            FROM pg_indexes pi
            JOIN pg_index pgi ON pi.indexname = (SELECT relname FROM pg_class WHERE oid = pgi.indexrelid)
            WHERE pi.tablename = 'picks'
        LOOP
            RAISE NOTICE 'Index: % (Type: %)', index_rec.indexname, index_rec.index_type;
        END LOOP;
    END $$;
    """, "-- Just for debugging"
  end
end
