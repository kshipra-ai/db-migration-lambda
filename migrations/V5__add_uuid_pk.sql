-- Ensure UUID generator is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- provides gen_random_uuid()

-- 1) Add a new UUID column with default
ALTER TABLE kshipra_core.user_profile
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();

-- 2) Backfill existing rows
UPDATE kshipra_core.user_profile
SET id = gen_random_uuid()
WHERE id IS NULL;

-- 3) Make it NOT NULL
ALTER TABLE kshipra_core.user_profile
  ALTER COLUMN id SET NOT NULL;

-- 4) Switch primary key to "id"
DO $$
BEGIN
  -- Drop old PK if it's still on user_id
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profile_pkey'
      AND conrelid = 'kshipra_core.user_profile'::regclass
  ) THEN
    ALTER TABLE kshipra_core.user_profile DROP CONSTRAINT user_profile_pkey;
  END IF;
END
$$ LANGUAGE plpgsql;

ALTER TABLE kshipra_core.user_profile
  ADD CONSTRAINT user_profile_pkey PRIMARY KEY (id);

-- 5) Keep Cognito sub unique (optional but recommended)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profile_user_id_key'
      AND conrelid = 'kshipra_core.user_profile'::regclass
  ) THEN
    ALTER TABLE kshipra_core.user_profile
      ADD CONSTRAINT user_profile_user_id_key UNIQUE (user_id);
  END IF;
END
$$ LANGUAGE plpgsql;
