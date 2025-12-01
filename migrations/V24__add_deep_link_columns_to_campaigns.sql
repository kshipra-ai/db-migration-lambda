-- V24: Add deep link columns to campaigns table
-- V19 was supposed to add these but was never actually applied

ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS deep_link VARCHAR(2048),
ADD COLUMN IF NOT EXISTS deep_link_title VARCHAR(255),
ADD COLUMN IF NOT EXISTS deep_link_description TEXT,
ADD COLUMN IF NOT EXISTS min_view_duration_seconds INTEGER DEFAULT 10,
ADD COLUMN IF NOT EXISTS deep_link_order INTEGER;

-- Add constraint to ensure valid deep link URL format
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_valid_deep_link' 
        AND connamespace = 'kshipra_core'::regnamespace
    ) THEN
        ALTER TABLE kshipra_core.campaigns 
        ADD CONSTRAINT check_valid_deep_link CHECK (deep_link IS NULL OR deep_link ~ '^https?://.*');
    END IF;
END $$;

-- Create unique index on deep_link_order for rotation sequence
CREATE UNIQUE INDEX IF NOT EXISTS idx_campaigns_deep_link_order 
ON kshipra_core.campaigns(deep_link_order) 
WHERE deep_link_order IS NOT NULL AND is_active = true;

-- Index for active deep links
CREATE INDEX IF NOT EXISTS idx_campaigns_active_deep_links 
ON kshipra_core.campaigns(is_active, deep_link_order) 
WHERE deep_link IS NOT NULL;

-- Update existing campaigns with deep links from landing_url
UPDATE kshipra_core.campaigns
SET 
    deep_link = landing_url,
    deep_link_title = campaign_name || ' - Featured Content',
    deep_link_description = 'Discover exclusive content and special offers from ' || campaign_name
WHERE landing_url IS NOT NULL AND deep_link IS NULL;

COMMENT ON COLUMN kshipra_core.campaigns.deep_link IS 'Deep link URL shown to users when they scan QR codes - part of global rotation pool';
COMMENT ON COLUMN kshipra_core.campaigns.min_view_duration_seconds IS 'Minimum time (in seconds) user must view link before it counts as completed';
COMMENT ON COLUMN kshipra_core.campaigns.deep_link_order IS 'Global sequential order for link rotation across all campaigns';
