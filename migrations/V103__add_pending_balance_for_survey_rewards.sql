-- V103__add_pending_balance_for_survey_rewards.sql
-- Add pending_balance column to track survey rewards awaiting webhook confirmation

DO $$
BEGIN
    -- Add pending_balance column to user_profile table
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'kshipra_core' AND table_name = 'user_profile'
    ) THEN
        -- Add pending_balance column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'kshipra_core' 
            AND table_name = 'user_profile' 
            AND column_name = 'pending_balance'
        ) THEN
            EXECUTE 'ALTER TABLE kshipra_core.user_profile ADD COLUMN pending_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00';
            RAISE NOTICE 'Added pending_balance column to user_profile table';
        END IF;
        
        -- Add comment to explain pending_balance
        EXECUTE 'COMMENT ON COLUMN kshipra_core.user_profile.pending_balance IS ''Survey rewards awaiting webhook confirmation before moving to cash_balance''';
    END IF;
END $$;