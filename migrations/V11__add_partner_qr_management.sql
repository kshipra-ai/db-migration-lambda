-- V11__add_partner_qr_management.sql
-- Add partner management and QR campaign tracking tables

-- Create partners table for brand management
CREATE TABLE IF NOT EXISTS kshipra_core.partners (
    partner_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_name VARCHAR(255) NOT NULL UNIQUE,
    brand_slug VARCHAR(100) NOT NULL UNIQUE, -- URL-friendly identifier
    landing_url TEXT NOT NULL, -- Partner's website/landing page
    logo_url TEXT, -- Partner brand logo
    contact_email VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    reward_rate INTEGER NOT NULL DEFAULT 25, -- Default points per engagement
    max_daily_rewards INTEGER NOT NULL DEFAULT 5, -- Anti-abuse limit
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create QR campaigns table for managing QR code assignments
CREATE TABLE IF NOT EXISTS kshipra_core.qr_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_code_id VARCHAR(100) NOT NULL UNIQUE, -- Kshipra QR identifier (e.g., KSH_QR_001)
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_description TEXT,
    engagement_type VARCHAR(50) NOT NULL DEFAULT 'page_visit', -- page_visit, purchase, signup
    reward_points INTEGER NOT NULL DEFAULT 25,
    max_daily_scans INTEGER NOT NULL DEFAULT 5,
    is_active BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create QR scans tracking table for analytics and abuse prevention
CREATE TABLE IF NOT EXISTS kshipra_core.qr_scans (
    scan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL REFERENCES kshipra_core.qr_campaigns(campaign_id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    qr_code_id VARCHAR(100) NOT NULL,
    points_awarded INTEGER NOT NULL DEFAULT 0,
    engagement_type VARCHAR(50) NOT NULL,
    user_agent TEXT, -- For analytics
    ip_address INET, -- For abuse detection
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_partners_brand_slug ON kshipra_core.partners(brand_slug);
CREATE INDEX IF NOT EXISTS idx_partners_is_active ON kshipra_core.partners(is_active);
CREATE INDEX IF NOT EXISTS idx_qr_campaigns_qr_code_id ON kshipra_core.qr_campaigns(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_qr_campaigns_partner_active ON kshipra_core.qr_campaigns(partner_id, is_active);
CREATE INDEX IF NOT EXISTS idx_qr_scans_user_date ON kshipra_core.qr_scans(user_id, scanned_at);
CREATE INDEX IF NOT EXISTS idx_qr_scans_campaign_date ON kshipra_core.qr_scans(campaign_id, scanned_at);
CREATE INDEX IF NOT EXISTS idx_qr_scans_daily_limit ON kshipra_core.qr_scans(user_id, qr_code_id, scanned_at);

-- Add updated_at trigger for partners table
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_partners_updated_at ON kshipra_core.partners;
CREATE TRIGGER update_partners_updated_at
    BEFORE UPDATE ON kshipra_core.partners
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_qr_campaigns_updated_at ON kshipra_core.qr_campaigns;
CREATE TRIGGER update_qr_campaigns_updated_at
    BEFORE UPDATE ON kshipra_core.qr_campaigns
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE kshipra_core.partners IS 'Partner brands that work with Kshipra for QR campaigns';
COMMENT ON TABLE kshipra_core.qr_campaigns IS 'QR code campaigns mapping Kshipra QR codes to partner brands';
COMMENT ON TABLE kshipra_core.qr_scans IS 'Tracking table for all QR code scans and reward distributions';

-- Insert sample partner for testing
INSERT INTO kshipra_core.partners (brand_name, brand_slug, landing_url, contact_email, reward_rate)
VALUES 
    ('Nike Store', 'nike-store', 'https://nike.com/sale', 'partner@nike.com', 30),
    ('Eco Market', 'eco-market', 'https://ecomarket.com/sustainable', 'info@ecomarket.com', 40)
ON CONFLICT (brand_name) DO NOTHING;

-- Insert sample QR campaigns
INSERT INTO kshipra_core.qr_campaigns (qr_code_id, partner_id, campaign_name, engagement_type, reward_points)
SELECT 
    'KSH_QR_001',
    p.partner_id,
    'Nike Summer Sale Campaign',
    'page_visit',
    30
FROM kshipra_core.partners p 
WHERE p.brand_slug = 'nike-store'
ON CONFLICT (qr_code_id) DO NOTHING;