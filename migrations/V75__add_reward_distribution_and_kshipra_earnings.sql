-- Migration V68: Add reward distribution configuration and Kshipra earnings tracking
-- This migration adds:
-- 1. reward_distribution_config table to configure how rewards are split
-- 2. kshipra_earnings table to track commission earnings
-- 3. Update existing campaigns and user_profile to support the new distribution

-- Create reward distribution configuration table
CREATE TABLE IF NOT EXISTS kshipra_core.reward_distribution_config (
    config_id SERIAL PRIMARY KEY,
    config_name VARCHAR(100) NOT NULL DEFAULT 'default',
    user_rewards_percentage NUMERIC(5,2) NOT NULL DEFAULT 50.00 CHECK (user_rewards_percentage >= 0 AND user_rewards_percentage <= 100),
    cashback_percentage NUMERIC(5,2) NOT NULL DEFAULT 25.00 CHECK (cashback_percentage >= 0 AND cashback_percentage <= 100),
    kshipra_commission_percentage NUMERIC(5,2) NOT NULL DEFAULT 25.00 CHECK (kshipra_commission_percentage >= 0 AND kshipra_commission_percentage <= 100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    CONSTRAINT total_percentage_check CHECK (user_rewards_percentage + cashback_percentage + kshipra_commission_percentage = 100)
);

-- Insert default configuration (50% user rewards, 25% cashback, 25% kshipra commission)
INSERT INTO kshipra_core.reward_distribution_config 
    (config_name, user_rewards_percentage, cashback_percentage, kshipra_commission_percentage, is_active, notes)
VALUES 
    ('default', 50.00, 25.00, 25.00, TRUE, 'Default reward distribution: 50% to user rewards, 25% to cashback, 25% to Kshipra commission')
ON CONFLICT DO NOTHING;

-- Create Kshipra earnings tracking table
CREATE TABLE IF NOT EXISTS kshipra_core.kshipra_earnings (
    earning_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    campaign_id VARCHAR(255),
    qr_code_id VARCHAR(255),
    source_type VARCHAR(50) NOT NULL, -- 'qr_scan', 'campaign_view', 'referral', etc.
    total_reward_points INT NOT NULL, -- Original reward points allocated by campaign
    commission_points INT NOT NULL, -- Points that went to Kshipra (commission)
    commission_percentage NUMERIC(5,2) NOT NULL,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_id UUID DEFAULT gen_random_uuid(),
    metadata JSONB, -- Additional data about the transaction
    notes TEXT,
    CONSTRAINT fk_kshipra_earnings_user FOREIGN KEY (user_id) REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_kshipra_earnings_user_id ON kshipra_core.kshipra_earnings(user_id);
CREATE INDEX IF NOT EXISTS idx_kshipra_earnings_campaign_id ON kshipra_core.kshipra_earnings(campaign_id);
CREATE INDEX IF NOT EXISTS idx_kshipra_earnings_earned_at ON kshipra_core.kshipra_earnings(earned_at DESC);
CREATE INDEX IF NOT EXISTS idx_kshipra_earnings_source_type ON kshipra_core.kshipra_earnings(source_type);
CREATE INDEX IF NOT EXISTS idx_kshipra_earnings_transaction_id ON kshipra_core.kshipra_earnings(transaction_id);

-- Create view for Kshipra earnings summary
CREATE OR REPLACE VIEW kshipra_core.v_kshipra_earnings_summary AS
SELECT 
    source_type,
    COUNT(*) as transaction_count,
    SUM(total_reward_points) as total_rewards_distributed,
    SUM(commission_points) as total_commission_earned,
    AVG(commission_percentage) as avg_commission_percentage,
    MIN(earned_at) as first_earning_date,
    MAX(earned_at) as last_earning_date
FROM kshipra_core.kshipra_earnings
GROUP BY source_type;

-- Create view for daily earnings summary
CREATE OR REPLACE VIEW kshipra_core.v_daily_kshipra_earnings AS
SELECT 
    DATE(earned_at) as earning_date,
    source_type,
    COUNT(*) as transaction_count,
    SUM(total_reward_points) as total_rewards_distributed,
    SUM(commission_points) as total_commission_earned
FROM kshipra_core.kshipra_earnings
GROUP BY DATE(earned_at), source_type
ORDER BY earning_date DESC, source_type;

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION kshipra_core.update_reward_distribution_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_reward_distribution_config_timestamp
    BEFORE UPDATE ON kshipra_core.reward_distribution_config
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_reward_distribution_config_timestamp();

-- Grant permissions (adjust as needed for your setup)
GRANT SELECT, INSERT, UPDATE ON kshipra_core.reward_distribution_config TO kshipra_admin;
GRANT SELECT, INSERT ON kshipra_core.kshipra_earnings TO kshipra_admin;
GRANT SELECT ON kshipra_core.v_kshipra_earnings_summary TO kshipra_admin;
GRANT SELECT ON kshipra_core.v_daily_kshipra_earnings TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.reward_distribution_config_config_id_seq TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.kshipra_earnings_earning_id_seq TO kshipra_admin;

-- Add comments for documentation
COMMENT ON TABLE kshipra_core.reward_distribution_config IS 'Configuration for how reward points are distributed between user rewards, cashback, and Kshipra commission';
COMMENT ON TABLE kshipra_core.kshipra_earnings IS 'Tracks all earnings/commissions that go to Kshipra from various reward activities';
COMMENT ON COLUMN kshipra_core.reward_distribution_config.user_rewards_percentage IS 'Percentage of reward points that go to user rewards_earned (redeemable for products)';
COMMENT ON COLUMN kshipra_core.reward_distribution_config.cashback_percentage IS 'Percentage of reward points that go to user cash_balance (redeemable for cash)';
COMMENT ON COLUMN kshipra_core.reward_distribution_config.kshipra_commission_percentage IS 'Percentage of reward points that go to Kshipra as commission';
COMMENT ON COLUMN kshipra_core.kshipra_earnings.source_type IS 'Type of activity that generated the earning: qr_scan, campaign_view, referral, etc.';
COMMENT ON COLUMN kshipra_core.kshipra_earnings.commission_points IS 'Amount of points/cents that went to Kshipra as commission';

-- Verify the migration
DO $$
BEGIN
    RAISE NOTICE 'Migration V68 completed successfully';
    RAISE NOTICE 'Created tables: reward_distribution_config, kshipra_earnings';
    RAISE NOTICE 'Created views: v_kshipra_earnings_summary, v_daily_kshipra_earnings';
    RAISE NOTICE 'Default distribution: 50%% user rewards, 25%% cashback, 25%% Kshipra commission';
END $$;
