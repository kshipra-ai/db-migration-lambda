-- V15__add_campaign_location_and_media.sql
-- Add location targeting, bag sponsorship, and media fields to campaigns table

-- Add new columns for enhanced campaign features
ALTER TABLE kshipra_core.campaigns
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS province VARCHAR(100),
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20),
ADD COLUMN IF NOT EXISTS country VARCHAR(100) DEFAULT 'Canada',
ADD COLUMN IF NOT EXISTS bag_volume INTEGER, -- Number of bags sponsored
ADD COLUMN IF NOT EXISTS media_type VARCHAR(20), -- 'image' or 'video'
ADD COLUMN IF NOT EXISTS media_url TEXT, -- S3 URL for uploaded media
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT; -- Thumbnail for video preview

-- Add indexes for location-based queries
CREATE INDEX IF NOT EXISTS idx_campaigns_city ON kshipra_core.campaigns(city) WHERE city IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_province ON kshipra_core.campaigns(province) WHERE province IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_postal_code ON kshipra_core.campaigns(postal_code) WHERE postal_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_location ON kshipra_core.campaigns(city, province, postal_code) WHERE city IS NOT NULL OR province IS NOT NULL OR postal_code IS NOT NULL;

-- Add index for bag volume (useful for inventory management)
CREATE INDEX IF NOT EXISTS idx_campaigns_bag_volume ON kshipra_core.campaigns(bag_volume) WHERE bag_volume IS NOT NULL;

-- Add constraints
ALTER TABLE kshipra_core.campaigns 
ADD CONSTRAINT check_positive_bag_volume CHECK (bag_volume IS NULL OR bag_volume > 0);

ALTER TABLE kshipra_core.campaigns 
ADD CONSTRAINT check_valid_media_type CHECK (media_type IS NULL OR media_type IN ('image', 'video'));

-- Add comments for documentation
COMMENT ON COLUMN kshipra_core.campaigns.city IS 'Target city for campaign';
COMMENT ON COLUMN kshipra_core.campaigns.province IS 'Target province/state for campaign';
COMMENT ON COLUMN kshipra_core.campaigns.postal_code IS 'Target postal code for campaign (can be partial for area targeting)';
COMMENT ON COLUMN kshipra_core.campaigns.country IS 'Target country for campaign (default: Canada)';
COMMENT ON COLUMN kshipra_core.campaigns.bag_volume IS 'Number of eco-bags sponsored for this campaign';
COMMENT ON COLUMN kshipra_core.campaigns.media_type IS 'Type of media uploaded: image or video';
COMMENT ON COLUMN kshipra_core.campaigns.media_url IS 'S3 URL for campaign image or video';
COMMENT ON COLUMN kshipra_core.campaigns.thumbnail_url IS 'S3 URL for video thumbnail (auto-generated for videos)';

COMMENT ON TABLE kshipra_core.campaigns IS 'Marketing campaigns created by brand partners with location targeting and bag sponsorship tracking';
