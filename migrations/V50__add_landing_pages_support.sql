-- V50: Add landing pages support for campaigns
-- Brands can now choose between external URL or Kshipra-hosted landing page

-- Create landing_pages table
CREATE TABLE IF NOT EXISTS kshipra_core.landing_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES kshipra_core.campaigns(campaign_id) ON DELETE CASCADE,
    
    -- Content
    media_type VARCHAR(10) NOT NULL CHECK (media_type IN ('image', 'video')),
    media_url TEXT NOT NULL,
    headline TEXT NOT NULL,
    description TEXT,
    cta_text VARCHAR(100) DEFAULT 'Learn More',
    cta_url TEXT, -- Optional: where CTA button redirects (e.g., brand website)
    
    -- Branding (optional customization)
    logo_url TEXT,
    primary_color VARCHAR(7) DEFAULT '#000000',
    background_color VARCHAR(7) DEFAULT '#FFFFFF',
    
    -- Analytics
    view_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- One landing page per campaign
    UNIQUE(campaign_id)
);

-- Add flag to campaigns table to indicate if using landing page
ALTER TABLE kshipra_core.campaigns 
    ADD COLUMN IF NOT EXISTS uses_landing_page BOOLEAN DEFAULT FALSE;

-- Make URL optional (campaigns can use either URL or landing page)
ALTER TABLE kshipra_core.campaigns 
    ALTER COLUMN landing_url DROP NOT NULL;

-- Add constraint: Either URL must be provided OR uses_landing_page must be true
ALTER TABLE kshipra_core.campaigns
    ADD CONSTRAINT campaign_must_have_url_or_landing_page 
    CHECK (
        (landing_url IS NOT NULL AND landing_url != '') OR 
        (uses_landing_page = TRUE)
    );

-- Indexes for performance
CREATE INDEX idx_landing_pages_campaign_id ON kshipra_core.landing_pages(campaign_id);
CREATE INDEX idx_campaigns_uses_landing_page ON kshipra_core.campaigns(uses_landing_page) WHERE uses_landing_page = TRUE;

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_landing_pages_updated_at
    BEFORE UPDATE ON kshipra_core.landing_pages
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_updated_at_column();

-- Backfill existing campaigns: set uses_landing_page = false (they all use external URLs)
UPDATE kshipra_core.campaigns 
SET uses_landing_page = FALSE 
WHERE uses_landing_page IS NULL;

-- Make uses_landing_page NOT NULL after backfill
ALTER TABLE kshipra_core.campaigns 
    ALTER COLUMN uses_landing_page SET NOT NULL;

-- Add comment for documentation
COMMENT ON TABLE kshipra_core.landing_pages IS 'Kshipra-hosted landing pages for campaigns. Brands can upload image/video with headline and CTA instead of providing external URL';
COMMENT ON COLUMN kshipra_core.campaigns.uses_landing_page IS 'If true, campaign uses Kshipra landing page. If false, campaign uses external URL';
COMMENT ON COLUMN kshipra_core.landing_pages.media_type IS 'Type of media: image or video';
COMMENT ON COLUMN kshipra_core.landing_pages.cta_url IS 'Optional URL where CTA button redirects (e.g., brand website, product page)';
