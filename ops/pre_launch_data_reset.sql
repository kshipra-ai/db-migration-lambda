-- =============================================================================
-- pre_launch_data_reset.sql
-- =============================================================================
-- PURPOSE:
--   Empty all USER-GENERATED data tables in kshipra_core before public launch,
--   while PRESERVING:
--     • Flyway migration history (so migrations don't replay)
--     • Application configuration (payment, reward, survey config, etc.)
--     • Reference catalogs (survey providers, etc.)
--
-- THIS FILE IS NOT A FLYWAY MIGRATION.
--   • It lives in db-migration-lambda/ops/ (not migrations/)
--   • It is invoked manually via run_data_reset.ps1 (queryOnly mode)
--   • It does NOT auto-run on deploy
--   • It does NOT modify flyway_schema_history
--
-- HOW IT WORKS:
--   1. Builds a list of all base tables in schema 'kshipra_core'
--   2. Removes the PRESERVE list (configs + flyway history)
--   3. TRUNCATEs the remainder with RESTART IDENTITY CASCADE
--   4. Returns a report of what was cleared / preserved / row counts
--
-- SAFETY:
--   • Wrapped in a transaction — any error rolls back the entire wipe
--   • session_replication_role = 'replica' defers FK checks during truncate
--   • Dynamic discovery — automatically picks up tables added after this script
--     was written, EXCEPT those in PRESERVE_TABLES
--
-- RUN ONLY AFTER:
--   1. Taking an RDS snapshot
--   2. Confirming you are pointed at the correct DB (kshipra_production)
--   3. Coordinating Cognito user pool reset (else login state goes stale)
-- =============================================================================

DO $$
DECLARE
  preserve_tables  text[] := ARRAY[
    -- DO NOT TOUCH — Flyway tracking
    'flyway_schema_history',

    -- Application configuration (would break the app if cleared)
    'system_configurations',
    'payment_config',
    'reward_distribution_config',
    'survey_revenue_config',

    -- Reference catalogs
    'survey_providers',

    -- Admin-only / internal tooling state (review and add/remove as needed)
    'pitch_kb_changes',
    'pitch_ceo_context',
    'pitch_custom_questions'
  ];
  cleared_tables   text[] := ARRAY[]::text[];
  preserved_count  int    := 0;
  cleared_count    int    := 0;
  truncate_sql     text;
  tbl_record       record;
BEGIN
  RAISE NOTICE '=============================================================';
  RAISE NOTICE 'Pre-launch data reset — kshipra_core';
  RAISE NOTICE 'DB: %', current_database();
  RAISE NOTICE 'Started at: %', clock_timestamp();
  RAISE NOTICE '=============================================================';

  SET LOCAL session_replication_role = 'replica';

  FOR tbl_record IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'kshipra_core'
      AND table_type   = 'BASE TABLE'
    ORDER BY table_name
  LOOP
    IF tbl_record.table_name = ANY(preserve_tables) THEN
      preserved_count := preserved_count + 1;
      RAISE NOTICE '[PRESERVED]  kshipra_core.%', tbl_record.table_name;
    ELSE
      cleared_tables := array_append(cleared_tables, tbl_record.table_name);
    END IF;
  END LOOP;

  IF array_length(cleared_tables, 1) IS NULL THEN
    RAISE NOTICE 'No tables to clear. Aborting.';
    RETURN;
  END IF;

  truncate_sql := 'TRUNCATE TABLE '
    || (
      SELECT string_agg(format('kshipra_core.%I', t), ', ')
      FROM unnest(cleared_tables) AS t
    )
    || ' RESTART IDENTITY CASCADE';

  RAISE NOTICE '-------------------------------------------------------------';
  RAISE NOTICE 'About to truncate % tables:', array_length(cleared_tables, 1);
  RAISE NOTICE '%', truncate_sql;
  RAISE NOTICE '-------------------------------------------------------------';

  EXECUTE truncate_sql;
  cleared_count := array_length(cleared_tables, 1);

  RAISE NOTICE '=============================================================';
  RAISE NOTICE 'DONE.';
  RAISE NOTICE 'Cleared:   % tables', cleared_count;
  RAISE NOTICE 'Preserved: % tables', preserved_count;
  RAISE NOTICE 'Finished at: %', clock_timestamp();
  RAISE NOTICE '=============================================================';
END $$;

-- Sanity check: row counts of preserved tables (should be > 0 for config tables)
SELECT
  'PRESERVED' AS status,
  table_name,
  (xpath('/row/c/text()',
         query_to_xml(format('SELECT COUNT(*) AS c FROM kshipra_core.%I', table_name),
                      false, true, '')))[1]::text::int AS row_count
FROM information_schema.tables
WHERE table_schema = 'kshipra_core'
  AND table_type   = 'BASE TABLE'
  AND table_name IN (
    'flyway_schema_history',
    'system_configurations',
    'payment_config',
    'reward_distribution_config',
    'survey_revenue_config',
    'survey_providers'
  )
ORDER BY table_name;
