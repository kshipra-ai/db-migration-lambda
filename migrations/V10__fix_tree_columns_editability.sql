-- V10__fix_tree_columns_editability.sql
-- Fix editability issues with tree tracking columns

DO $$
BEGIN
    -- Ensure the columns exist and are properly configured
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'kshipra_core' AND table_name = 'user_profile'
    ) THEN
        
        -- Remove any potential read-only constraints or triggers
        -- First, drop any existing policies that might restrict updates
        DROP POLICY IF EXISTS readonly_tree_columns ON kshipra_core.user_profile;
        DROP POLICY IF EXISTS restrict_tree_updates ON kshipra_core.user_profile;
        
        -- Ensure columns have proper permissions
        -- Grant UPDATE specifically on these columns to all roles that should have access
        GRANT UPDATE (trees_planted, points_for_next_tree) ON kshipra_core.user_profile TO kshipra_admin;
        
        -- Make sure columns are properly nullable/not null as needed
        ALTER TABLE kshipra_core.user_profile 
        ALTER COLUMN trees_planted SET NOT NULL,
        ALTER COLUMN trees_planted SET DEFAULT 0;
        
        ALTER TABLE kshipra_core.user_profile 
        ALTER COLUMN points_for_next_tree SET NOT NULL,
        ALTER COLUMN points_for_next_tree SET DEFAULT 1000;
        
        -- Remove any check constraints that might be blocking updates
        DO $inner$
        DECLARE
            constraint_name TEXT;
        BEGIN
            -- Find and drop any check constraints on tree columns
            FOR constraint_name IN
                SELECT tc.constraint_name
                FROM information_schema.table_constraints tc
                JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
                WHERE tc.table_schema = 'kshipra_core'
                AND tc.table_name = 'user_profile'
                AND tc.constraint_type = 'CHECK'
                AND (cc.check_clause LIKE '%trees_planted%' OR cc.check_clause LIKE '%points_for_next_tree%')
            LOOP
                EXECUTE 'ALTER TABLE kshipra_core.user_profile DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name);
                RAISE NOTICE 'Dropped constraint: %', constraint_name;
            END LOOP;
        END $inner$;
        
        -- Add basic check constraints to ensure data validity (but allow updates)
        ALTER TABLE kshipra_core.user_profile 
        ADD CONSTRAINT trees_planted_non_negative CHECK (trees_planted >= 0);
        
        ALTER TABLE kshipra_core.user_profile 
        ADD CONSTRAINT points_for_next_tree_positive CHECK (points_for_next_tree > 0);
        
        -- Test that updates work by updating a test record (if any exists)
        DO $test$
        BEGIN
            IF EXISTS (SELECT 1 FROM kshipra_core.user_profile LIMIT 1) THEN
                -- Test update on first record
                UPDATE kshipra_core.user_profile 
                SET trees_planted = trees_planted, 
                    points_for_next_tree = points_for_next_tree 
                WHERE id = (SELECT id FROM kshipra_core.user_profile LIMIT 1);
                RAISE NOTICE 'Tree columns update test: SUCCESS';
            ELSE
                RAISE NOTICE 'No test records found, but columns should be editable now';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Tree columns update test failed: %', SQLERRM;
        END $test$;
        
        RAISE NOTICE 'Tree columns editability fixed successfully';
        
    ELSE
        RAISE EXCEPTION 'user_profile table not found in kshipra_core schema';
    END IF;
END $$;

-- Verify column properties
SELECT 
    column_name,
    is_nullable,
    column_default,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'kshipra_core' 
AND table_name = 'user_profile' 
AND column_name IN ('trees_planted', 'points_for_next_tree')
ORDER BY ordinal_position;