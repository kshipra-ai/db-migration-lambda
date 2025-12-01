DO $$
DECLARE
  app_has_objects boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'app'
      AND c.relkind IN ('r','v','m','S','f','p')  -- tables/views/mviews/sequences/foreign/partitioned
  ) INTO app_has_objects;

  IF NOT app_has_objects THEN
    EXECUTE 'DROP SCHEMA IF EXISTS app';
  END IF;
END
$$ LANGUAGE plpgsql;
