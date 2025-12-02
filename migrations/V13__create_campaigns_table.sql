-- V13__create_campaigns_table.sql
-- Create campaigns table for brand marketing campaigns

CREATE TABLE IF NOT EXISTS kshipra_core.campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    
    -- Campaign Details
    campaign_name VARCHAR(255) NOT NULL,
    campaign_description TEXT,
    landing_url VARCHAR(2048) NOT NULL,
    
    -- Reward Configuration
    reward_rate INTEGER NOT NULL DEFAULT 25, -- Points per engagement
    max_daily_rewards INTEGER NOT NULL DEFAULT 5, -- Anti-abuse limit
    
    -- Campaign Status & Timing
    is_active BOOLEAN NOT NULL DEFAULT true,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP WITH TIME ZONE,
    
    -- Budget & Limits
    total_budget INTEGER, -- Total points budget for campaign
    daily_budget INTEGER, -- Daily points budget
    
    -- Tracking
    total_engagements INTEGER DEFAULT 0,
    total_points_awarded INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for performance
CREATE INDEX idx_campaigns_partner_id ON kshipra_core.campaigns(partner_id);
CREATE INDEX idx_campaigns_active ON kshipra_core.campaigns(is_active) WHERE is_active = true;
CREATE INDEX idx_campaigns_dates ON kshipra_core.campaigns(start_date, end_date);

-- Add constraint to ensure positive values
ALTER TABLE kshipra_core.campaigns ADD CONSTRAINT check_positive_reward_rate 
    CHECK (reward_rate > 0);
ALTER TABLE kshipra_core.campaigns ADD CONSTRAINT check_positive_max_daily 
    CHECK (max_daily_rewards > 0);

-- Update function for updated_at timestamp
CREATE OR REPLACE FUNCTION kshipra_core.update_campaigns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-updating updated_at
CREATE TRIGGER trigger_campaigns_updated_at
    BEFORE UPDATE ON kshipra_core.campaigns
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_campaigns_updated_at();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.campaigns TO kshipra_admin;

-- Insert single default campaign pointing to kshipraai.com
-- This will be used when no other campaigns are available
INSERT INTO kshipra_core.campaigns (partner_id, campaign_name, campaign_description, landing_url, reward_rate, max_daily_rewards)
SELECT 
    partner_id,
    'Kshipra Default Campaign' as campaign_name,
    'Default campaign - learn more about sustainable shopping with Kshipra' as campaign_description,
    'https://www.kshipraai.com' as landing_url,
    10 as reward_rate,
    10 as max_daily_rewards
FROM kshipra_core.partners
WHERE brand_name = 'Kshipra Universal'
LIMIT 1
ON CONFLICT DO NOTHING;