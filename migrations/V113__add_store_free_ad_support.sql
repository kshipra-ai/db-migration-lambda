-- Migration V113: Add store role and free ad support
-- Date: 2026-01-17
-- Description: Add columns to campaigns table to support store free ads that are auto-displayed

-- Add columns to campaigns table for store free ads
ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS is_store_free_ad BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS auto_display BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS scannable BOOLEAN DEFAULT TRUE;

-- Add comments
COMMENT ON COLUMN kshipra_core.campaigns.is_store_free_ad IS 'True if this is a store''s first free ad';
COMMENT ON COLUMN kshipra_core.campaigns.auto_display IS 'True if ad should be auto-displayed in user dashboard without QR scan';
COMMENT ON COLUMN kshipra_core.campaigns.scannable IS 'True if ad is accessible via QR scan (false for free store ads)';

-- Create index for querying auto-display ads (for user dashboard)
CREATE INDEX IF NOT EXISTS idx_campaigns_auto_display 
ON kshipra_core.campaigns(auto_display, active) 
WHERE auto_display = TRUE;

-- Create index for checking if store has free ad
CREATE INDEX IF NOT EXISTS idx_campaigns_store_free 
ON kshipra_core.campaigns(partner_id, is_store_free_ad) 
WHERE is_store_free_ad = TRUE;

-- Create index for scannable campaigns (for QR scan filtering)
CREATE INDEX IF NOT EXISTS idx_campaigns_scannable 
ON kshipra_core.campaigns(scannable, active) 
WHERE scannable = TRUE;
