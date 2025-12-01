-- V8__add_tree_tracking.sql
-- Add tree tracking columns to kshipra_core.user_profile table

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='kshipra_core' AND table_name='user_profile'
  ) THEN
    -- Add trees_planted column (tracks total trees planted by this user)
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             ADD COLUMN IF NOT EXISTS trees_planted INTEGER NOT NULL DEFAULT 0';
    
    -- Add points_for_next_tree column (tracks how many points needed for next tree, default 1000)
    EXECUTE 'ALTER TABLE kshipra_core.user_profile
             ADD COLUMN IF NOT EXISTS points_for_next_tree INTEGER NOT NULL DEFAULT 1000';
             
    -- Add comment to explain the tree planting logic
    EXECUTE 'COMMENT ON COLUMN kshipra_core.user_profile.trees_planted IS ''Total number of trees planted by this user through reward points''';
    EXECUTE 'COMMENT ON COLUMN kshipra_core.user_profile.points_for_next_tree IS ''Points required to plant the next tree (typically 1000)''';
  ELSE
    RAISE EXCEPTION 'kshipra_core.user_profile table not found';
  END IF;
END
$$ LANGUAGE plpgsql;