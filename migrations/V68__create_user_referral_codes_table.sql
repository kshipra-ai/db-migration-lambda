-- Migration V68: Create user_referral_codes table for multiple codes per user
-- This allows each user to generate multiple referral codes (admin-configurable limit)

-- Create user_referral_codes table
CREATE TABLE IF NOT EXISTS kshipra_core.user_referral_codes (
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    referral_code VARCHAR(20) UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT false,
    used_by_user_id VARCHAR(255) REFERENCES kshipra_core.user_profile(user_id) ON DELETE SET NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_usage CHECK (
        (is_used = false AND used_by_user_id IS NULL AND used_at IS NULL) OR
        (is_used = true AND used_by_user_id IS NOT NULL AND used_at IS NOT NULL)
    )
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_user ON kshipra_core.user_referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_code ON kshipra_core.user_referral_codes(referral_code);
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_used ON kshipra_core.user_referral_codes(is_used);

-- Migrate existing referral codes from user_profile to new table
INSERT INTO kshipra_core.user_referral_codes (user_id, referral_code, is_used)
SELECT 
    user_id, 
    referral_code,
    false
FROM kshipra_core.user_profile
WHERE referral_code IS NOT NULL
ON CONFLICT (referral_code) DO NOTHING;

-- Update system configuration to include max_codes_per_user
UPDATE kshipra_core.system_configurations
SET config_value = jsonb_set(
    config_value,
    '{max_codes_per_user}',
    '10'::jsonb
)
WHERE config_key = 'referral_system';

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.user_referral_codes TO lambda_tree_planting;

-- Add comment
COMMENT ON TABLE kshipra_core.user_referral_codes IS 'Stores multiple referral codes per user, each code can be used once';
COMMENT ON COLUMN kshipra_core.user_referral_codes.is_used IS 'True if this specific code has been used by someone';
COMMENT ON COLUMN kshipra_core.user_referral_codes.used_by_user_id IS 'User ID of the person who used this code';
