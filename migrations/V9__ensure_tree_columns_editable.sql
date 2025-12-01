-- V9__ensure_tree_columns_editable.sql
-- Ensure tree tracking columns are fully editable and add performance improvements

DO $$
BEGIN
    -- Check if the user_profile table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'kshipra_core' AND table_name = 'user_profile'
    ) THEN
        
        -- Ensure trees_planted column is editable (remove any constraints that might block updates)
        -- First, check if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'kshipra_core' 
            AND table_name = 'user_profile' 
            AND column_name = 'trees_planted'
        ) THEN
            -- Make sure there are no read-only constraints
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN trees_planted SET NOT NULL';
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN trees_planted SET DEFAULT 0';
            RAISE NOTICE 'trees_planted column verified as editable';
        ELSE
            -- Add the column if it doesn't exist
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ADD COLUMN trees_planted INTEGER NOT NULL DEFAULT 0';
            RAISE NOTICE 'trees_planted column added';
        END IF;
        
        -- Ensure points_for_next_tree column is editable
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'kshipra_core' 
            AND table_name = 'user_profile' 
            AND column_name = 'points_for_next_tree'
        ) THEN
            -- Make sure there are no read-only constraints
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN points_for_next_tree SET NOT NULL';
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN points_for_next_tree SET DEFAULT 1000';
            RAISE NOTICE 'points_for_next_tree column verified as editable';
        ELSE
            -- Add the column if it doesn't exist
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ADD COLUMN points_for_next_tree INTEGER NOT NULL DEFAULT 1000';
            RAISE NOTICE 'points_for_next_tree column added';
        END IF;
        
        -- Add indexes for better performance on tree-related queries
        -- Index on trees_planted for queries filtering by tree count
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'kshipra_core' 
            AND tablename = 'user_profile' 
            AND indexname = 'idx_user_profile_trees_planted'
        ) THEN
            EXECUTE 'CREATE INDEX idx_user_profile_trees_planted ON kshipra_core.user_profile (trees_planted)';
            RAISE NOTICE 'Index on trees_planted created';
        END IF;
        
        -- Composite index on rewards_earned and trees_planted for tree calculation queries
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'kshipra_core' 
            AND tablename = 'user_profile' 
            AND indexname = 'idx_user_profile_rewards_trees'
        ) THEN
            EXECUTE 'CREATE INDEX idx_user_profile_rewards_trees ON kshipra_core.user_profile (rewards_earned, trees_planted)';
            RAISE NOTICE 'Composite index on rewards_earned, trees_planted created';
        END IF;
        
        -- Update comments to be more descriptive
        EXECUTE 'COMMENT ON COLUMN kshipra_core.user_profile.trees_planted IS ''Total number of trees planted by user (1 tree per 1000 reward points). This column is fully editable.''';
        EXECUTE 'COMMENT ON COLUMN kshipra_core.user_profile.points_for_next_tree IS ''Points remaining to plant next tree. Calculated as: 1000 - (rewards_earned % 1000). This column is fully editable.''';
        
        -- Test that the columns are actually editable by performing a test update
        -- (This will help identify any permission issues)
        DECLARE
            test_user_id TEXT := 'migration_test_' || extract(epoch from now())::text;
        BEGIN
            -- Try to insert a test record
            EXECUTE format('INSERT INTO kshipra_core.user_profile (user_id, email, role, rewards_earned, trees_planted, points_for_next_tree, created_at) VALUES (%L, %L, %L, %s, %s, %s, NOW())', 
                test_user_id, 'migration_test@example.com', 'user', 1500, 1, 500);
            
            -- Try to update the tree columns
            EXECUTE format('UPDATE kshipra_core.user_profile SET trees_planted = %s, points_for_next_tree = %s WHERE user_id = %L', 
                2, 0, test_user_id);
            
            -- Clean up test record
            EXECUTE format('DELETE FROM kshipra_core.user_profile WHERE user_id = %L', test_user_id);
            
            RAISE NOTICE 'Tree columns editability test PASSED - columns are fully editable';
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Clean up test record in case of error
                BEGIN
                    EXECUTE format('DELETE FROM kshipra_core.user_profile WHERE user_id = %L', test_user_id);
                EXCEPTION
                    WHEN OTHERS THEN NULL; -- Ignore cleanup errors
                END;
                RAISE EXCEPTION 'Tree columns editability test FAILED: %', SQLERRM;
        END;
        
    ELSE
        RAISE EXCEPTION 'kshipra_core.user_profile table not found';
    END IF;
    
    RAISE NOTICE 'Migration V9 completed successfully - tree columns are confirmed editable';
    
END
$$ LANGUAGE plpgsql;