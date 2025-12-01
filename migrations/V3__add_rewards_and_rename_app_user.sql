-- V3__add_rewards_and_rename_app_user.sql
-- Idempotent: finds the table wherever it is, adds the column, renames/moves to kshipra_core.user_profile.

DO $$
DECLARE
  has_core_user_profile  boolean;
  has_core_app_user      boolean;
  has_app_user_profile   boolean;
  has_app_app_user       boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='user_profile'
  ) INTO has_core_user_profile;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='app_user'
  ) INTO has_core_app_user;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='app' AND table_name='user_profile'
  ) INTO has_app_user_profile;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='app' AND table_name='app_user'
  ) INTO has_app_app_user;

  IF has_core_user_profile THEN
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';

  ELSIF has_core_app_user THEN
    EXECUTE 'ALTER TABLE kshipra_core.app_user
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE kshipra_core.app_user RENAME TO user_profile';

  ELSIF has_app_user_profile THEN
    EXECUTE 'ALTER TABLE app.user_profile
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE app.user_profile SET SCHEMA kshipra_core';

  ELSIF has_app_app_user THEN
    EXECUTE 'ALTER TABLE app.app_user
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE app.app_user RENAME TO user_profile';
    EXECUTE 'ALTER TABLE app.user_profile SET SCHEMA kshipra_core';

  ELSE
    RAISE EXCEPTION 'No app_user/user_profile table found in app or kshipra_core';
  END IF;

  -- Optional: tidy PK constraint name if it used the old table name
  IF EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE c.conname = 'app_user_pkey'
      AND n.nspname = 'kshipra_core'
      AND t.relname = 'user_profile'
  ) THEN
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             RENAME CONSTRAINT app_user_pkey TO user_profile_pkey';
  END IF;
END$$;
