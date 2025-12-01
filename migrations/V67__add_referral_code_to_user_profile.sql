-- V67: Add referral_code column to user_profile table
-- This stores each user's unique referral code for the "Refer a Friend" feature

ALTER TABLE kshipra_core.user_profile
ADD COLUMN IF NOT EXISTS referral_code VARCHAR(20) UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profile_referral_code 
ON kshipra_core.user_profile(referral_code);

-- Generate referral codes for existing users (simple format: KSH + first 6 chars of user_id hash)
UPDATE kshipra_core.user_profile
SET referral_code = 'KSH' || UPPER(SUBSTRING(MD5(user_id) FROM 1 FOR 6))
WHERE referral_code IS NULL;
