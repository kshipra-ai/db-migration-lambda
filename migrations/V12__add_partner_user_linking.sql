-- V12__add_partner_user_linking.sql
-- Add user_id reference to partners table to link brand users with their partner entries

DO $$
BEGIN
    -- Add user_id column to partners table to link with user_profile
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'kshipra_core' AND table_name = 'partners'
    ) THEN
        -- Add user_id column to link partner with user_profile
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'kshipra_core' 
            AND table_name = 'partners' 
            AND column_name = 'user_id'
        ) THEN
            EXECUTE 'ALTER TABLE kshipra_core.partners ADD COLUMN user_id TEXT REFERENCES kshipra_core.user_profile(user_id) ON DELETE SET NULL';
            RAISE NOTICE 'Added user_id column to partners table';
        END IF;
        
        -- Add unique constraint to ensure one partner per user
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_schema = 'kshipra_core' 
            AND table_name = 'partners' 
            AND constraint_name = 'unique_partner_user_id'
        ) THEN
            EXECUTE 'ALTER TABLE kshipra_core.partners ADD CONSTRAINT unique_partner_user_id UNIQUE (user_id)';
            RAISE NOTICE 'Added unique constraint on partner user_id';
        END IF;
        
        -- Add index for performance on user_id lookups
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'kshipra_core' 
            AND tablename = 'partners' 
            AND indexname = 'idx_partners_user_id'
        ) THEN
            EXECUTE 'CREATE INDEX idx_partners_user_id ON kshipra_core.partners (user_id)';
            RAISE NOTICE 'Created index on partners.user_id';
        END IF;
        
        -- Add comment for clarity
        EXECUTE 'COMMENT ON COLUMN kshipra_core.partners.user_id IS ''Links partner entry to user_profile.user_id for brand users. Allows automatic partner creation during brand signup.''';
        
        RAISE NOTICE 'Partner-user linking migration completed successfully';
    ELSE
        RAISE EXCEPTION 'Partners table not found. Please ensure V11__add_partner_qr_management.sql has been applied first.';
    END IF;
END
$$ LANGUAGE plpgsql;