-- V44__add_partner_redemption_limits.sql
-- Add redemption limits per partner/brand

-- Add column for maximum points per redemption transaction
ALTER TABLE kshipra_core.partners
ADD COLUMN IF NOT EXISTS max_redemption_per_transaction INTEGER NOT NULL DEFAULT 1000;

-- Add column for minimum points per redemption transaction
ALTER TABLE kshipra_core.partners
ADD COLUMN IF NOT EXISTS min_redemption_per_transaction INTEGER NOT NULL DEFAULT 1;

-- Add comment
COMMENT ON COLUMN kshipra_core.partners.max_redemption_per_transaction IS 'Maximum points allowed per single redemption transaction (default 1000)';
COMMENT ON COLUMN kshipra_core.partners.min_redemption_per_transaction IS 'Minimum points required per redemption transaction (default 1)';

-- Update existing partners to have default limit
UPDATE kshipra_core.partners
SET max_redemption_per_transaction = 1000,
    min_redemption_per_transaction = 1
WHERE max_redemption_per_transaction IS NULL OR min_redemption_per_transaction IS NULL;
