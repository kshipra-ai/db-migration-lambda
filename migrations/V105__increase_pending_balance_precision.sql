-- V105__increase_pending_balance_precision.sql
-- Increase pending_balance column precision from DECIMAL(10,2) to DECIMAL(10,3)
-- This allows storing smaller amounts like $0.007 from Google ads

DO $$
BEGIN
    -- Check if pending_balance column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'pending_balance'
    ) THEN
        -- Alter column to support 3 decimal places
        EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN pending_balance TYPE DECIMAL(10,3)';
        RAISE NOTICE 'Changed pending_balance precision from DECIMAL(10,2) to DECIMAL(10,3)';
    ELSE
        RAISE NOTICE 'pending_balance column does not exist - skipping';
    END IF;
END $$;
