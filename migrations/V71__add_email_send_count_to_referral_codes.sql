-- Migration V71: Add email_send_count to track resend attempts
-- Limit resending to max 3 times per code

-- Add email_send_count column
ALTER TABLE kshipra_core.user_referral_codes 
ADD COLUMN IF NOT EXISTS email_send_count INT DEFAULT 0;

-- Update existing records where email was sent to set count to 1
UPDATE kshipra_core.user_referral_codes 
SET email_send_count = 1 
WHERE email_sent = true AND email_send_count = 0;

-- Add index
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_send_count 
ON kshipra_core.user_referral_codes(email_send_count) 
WHERE email_send_count > 0;

-- Add comment
COMMENT ON COLUMN kshipra_core.user_referral_codes.email_send_count IS 'Number of times email was sent for this code (max 3 allowed)';
