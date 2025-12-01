-- Migration: Add cash balance bucket for cashout rewards
-- This migration adds a separate cash_balance column to track cashback rewards
-- that can be cashed out, separate from regular points rewards

-- Add cash_balance column to user_profile table
ALTER TABLE kshipra_core.user_profile
ADD COLUMN IF NOT EXISTS cash_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00;

-- Add comment for clarity
COMMENT ON COLUMN kshipra_core.user_profile.cash_balance IS 'Cash rewards that can be cashed out (e.g., from referrals)';
COMMENT ON COLUMN kshipra_core.user_profile.rewards_earned IS 'Points rewards for redemptions and activities';

-- Create index for cash balance queries
CREATE INDEX IF NOT EXISTS idx_user_profile_cash_balance ON kshipra_core.user_profile(cash_balance) WHERE cash_balance > 0;

-- Update system configuration to use cash rewards for referrals
UPDATE kshipra_core.system_configurations
SET config_value = jsonb_set(
    jsonb_set(
        config_value,
        '{referrer_reward,type}',
        '"cash"'
    ),
    '{referee_reward,type}',
    '"cash"'
)
WHERE config_key = 'referral_system';

-- Add constraint to ensure cash_balance is never negative
ALTER TABLE kshipra_core.user_profile
ADD CONSTRAINT check_cash_balance_non_negative CHECK (cash_balance >= 0);

-- Grant permissions to lambda user
GRANT UPDATE ON kshipra_core.user_profile TO lambda_tree_planting;
