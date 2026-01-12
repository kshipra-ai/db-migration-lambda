-- V112__increase_cash_balance_precision.sql
-- Increase cash_balance column precision from DECIMAL(10,2) to DECIMAL(10,4)
-- This allows storing fractional cent amounts like $0.007 without rounding to $0.00

DO $$
BEGIN
    -- Check if cash_balance column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'cash_balance'
    ) THEN
        -- Alter column to support 4 decimal places for micro-payments
        EXECUTE 'ALTER TABLE kshipra_core.user_profile ALTER COLUMN cash_balance TYPE DECIMAL(10,4)';
        RAISE NOTICE 'Changed cash_balance precision from DECIMAL(10,2) to DECIMAL(10,4)';
    ELSE
        RAISE NOTICE 'cash_balance column does not exist - skipping';
    END IF;
END $$;

-- Add comment to document the precision change
COMMENT ON COLUMN kshipra_core.user_profile.cash_balance IS 'User cash balance in USD with 4 decimal places precision to support micro-payments like $0.007';