-- V115__add_store_role_and_campaign_flags.sql
-- Add support for 'store' role and campaign scannable flags

-- Add new columns to campaigns table
ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS is_store_free_ad BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS auto_display BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS scannable BOOLEAN NOT NULL DEFAULT TRUE;

-- Add index for filtering non-scannable campaigns in QR scan queries
CREATE INDEX IF NOT EXISTS idx_campaigns_scannable 
ON kshipra_core.campaigns(scannable) WHERE scannable = true;

-- Add index for auto-display campaigns (used in user dashboard)
CREATE INDEX IF NOT EXISTS idx_campaigns_auto_display 
ON kshipra_core.campaigns(auto_display, is_active, deleted, review_status) 
WHERE auto_display = true;

-- Add index for store free ads (used in campaign creation logic)
CREATE INDEX IF NOT EXISTS idx_campaigns_store_free_ad 
ON kshipra_core.campaigns(partner_id, is_store_free_ad) 
WHERE is_store_free_ad = true;

-- Add comments for documentation
COMMENT ON COLUMN kshipra_core.campaigns.is_store_free_ad IS 
'Indicates if this is a free auto-generated ad for a store (first campaign only)';

COMMENT ON COLUMN kshipra_core.campaigns.auto_display IS 
'Indicates if this campaign should auto-display in user dashboards (e.g., store free ads)';

COMMENT ON COLUMN kshipra_core.campaigns.scannable IS 
'Indicates if this campaign can be scanned via QR code for rewards. Free store ads are not scannable.';
