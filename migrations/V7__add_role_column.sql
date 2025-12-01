-- V7__add_role_column.sql
-- Add role column to kshipra_core.user_profile table

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='user_profile'
  ) THEN
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             ADD COLUMN IF NOT EXISTS role TEXT';
  END IF;
END
$$ LANGUAGE plpgsql;