DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'kshipra_core')
     AND EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'app') THEN
    EXECUTE 'ALTER SCHEMA app RENAME TO kshipra_core';
  END IF;
END$$;