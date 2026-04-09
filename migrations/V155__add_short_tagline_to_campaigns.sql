-- Add short_tagline column to campaigns table
-- This field is shown below the ad image in the user dashboard (max 150 chars)
-- The long campaign_description remains for internal/AI use only
ALTER TABLE kshipra_core.campaigns
ADD COLUMN IF NOT EXISTS short_tagline VARCHAR(150);
