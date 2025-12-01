-- V4__consolidate_app_into_kshipra_core.sql
-- Goal: end with table kshipra_core.user_profile and column rewards_earned

-- Ensure target schema exists
CREATE SCHEMA IF NOT EXISTS kshipra_core;

-- Case A: if kshipra_core.user_profile exists, ensure column
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='user_profile'
  ) THEN
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
  END IF;
END
$$ LANGUAGE plpgsql;

-- Case B: if kshipra_core.app_user exists, add column then rename
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='app_user'
  ) THEN
    EXECUTE 'ALTER TABLE kshipra_core.app_user
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE kshipra_core.app_user RENAME TO user_profile';
  END IF;
END
$$ LANGUAGE plpgsql;

-- Case C: if app.user_profile exists, add column then move to kshipra_core
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='app' AND table_name='user_profile'
  ) THEN
    EXECUTE 'ALTER TABLE app.user_profile
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE app.user_profile SET SCHEMA kshipra_core';
  END IF;
END
$$ LANGUAGE plpgsql;

-- Case D: if app.app_user exists, add column, rename, then move
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='app' AND table_name='app_user'
  ) THEN
    EXECUTE 'ALTER TABLE app.app_user
             ADD COLUMN IF NOT EXISTS rewards_earned INTEGER NOT NULL DEFAULT 0';
    EXECUTE 'ALTER TABLE app.app_user RENAME TO user_profile';
    EXECUTE 'ALTER TABLE app.user_profile SET SCHEMA kshipra_core';
  END IF;
END
$$ LANGUAGE plpgsql;

-- Tidy PK constraint name if still the old one
DO $$
BEGIN
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
END
$$ LANGUAGE plpgsql;

-- Optional: drop empty 'app' schema
DO $$
DECLARE
  app_has_objects boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'app'
      AND c.relkind IN ('r','v','m','S','f','p')
  ) INTO app_has_objects;

  IF NOT app_has_objects THEN
    BEGIN
      EXECUTE 'DROP SCHEMA app';
    EXCEPTION WHEN OTHERS THEN
      -- ignore if not empty / perms
      NULL;
    END;
  END IF;
END
$$ LANGUAGE plpgsql;
