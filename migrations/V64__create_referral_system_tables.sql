-- Migration: Create referral system tables and configuration
-- This migration creates tables for the refer-a-friend feature with cashback rewards

-- Create system_configurations table for global app settings
CREATE TABLE IF NOT EXISTS kshipra_core.system_configurations (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value JSONB NOT NULL DEFAULT '{}'::jsonb,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255)
);

-- Create referrals table to track referral relationships
CREATE TABLE IF NOT EXISTS kshipra_core.referrals (
    referral_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_user_id VARCHAR(255) NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    referred_user_id VARCHAR(255) NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    referral_code VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    source VARCHAR(50) DEFAULT 'mobile_app', -- mobile_app, web, etc.
    metadata JSONB DEFAULT '{}'::jsonb,

    CONSTRAINT different_users CHECK (referrer_user_id != referred_user_id),
    CONSTRAINT unique_referral UNIQUE (referrer_user_id, referred_user_id)
);

-- Create referral_rewards table to track cashback earnings
CREATE TABLE IF NOT EXISTS kshipra_core.referral_rewards (
    reward_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_id UUID NOT NULL REFERENCES kshipra_core.referrals(referral_id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    reward_type VARCHAR(20) DEFAULT 'cashback' CHECK (reward_type IN ('cashback', 'points', 'discount')),
    reward_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'credited', 'failed', 'expired')),
    credited_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON kshipra_core.referrals(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON kshipra_core.referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON kshipra_core.referrals(status);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON kshipra_core.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_user ON kshipra_core.referral_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_status ON kshipra_core.referral_rewards(status);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referral ON kshipra_core.referral_rewards(referral_id);
CREATE INDEX IF NOT EXISTS idx_system_configurations_active ON kshipra_core.system_configurations(is_active);

-- Insert default referral system configuration
INSERT INTO kshipra_core.system_configurations (config_key, config_value, description) VALUES
('referral_system', '{
    "enabled": false,
    "referrer_reward": {
        "amount": 50,
        "currency": "INR",
        "type": "cashback"
    },
    "referee_reward": {
        "amount": 25,
        "currency": "INR",
        "type": "cashback"
    },
    "max_referrals_per_user": 100,
    "referral_expiry_days": 30,
    "reward_expiry_days": 90,
    "min_referral_actions": 3,
    "required_actions": ["signup", "first_scan", "first_redemption"]
}'::jsonb, 'Referral system configuration including rewards, limits, and feature toggles')
ON CONFLICT (config_key) DO NOTHING;

-- Grant permissions to lambda user (following pattern from V17)
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.system_configurations TO lambda_tree_planting;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.referrals TO lambda_tree_planting;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.referral_rewards TO lambda_tree_planting;

-- Admin permissions are already covered by kshipra_admin role

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION kshipra_core.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for system_configurations
CREATE TRIGGER update_system_configurations_updated_at
    BEFORE UPDATE ON kshipra_core.system_configurations
    FOR EACH ROW EXECUTE FUNCTION kshipra_core.update_updated_at_column();
