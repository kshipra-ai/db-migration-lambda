-- Migration V69: Add email_sent tracking to user_referral_codes
-- This allows us to track which codes have been shared via email (pending referrals)

-- Add email_sent column
ALTER TABLE kshipra_core.user_referral_codes 
ADD COLUMN IF NOT EXISTS email_sent BOOLEAN DEFAULT false;

-- Add index for querying pending referrals (email sent but not used)
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_pending 
ON kshipra_core.user_referral_codes(user_id, email_sent, is_used) 
WHERE email_sent = true AND is_used = false;

-- Add comment
COMMENT ON COLUMN kshipra_core.user_referral_codes.email_sent IS 'True if this code has been sent via email invitation (counts as pending referral)';
