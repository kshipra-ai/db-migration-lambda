-- Migration V70: Add sent_to_email to track email recipient for each code
-- This ensures codes can only be resent to the original recipient

-- Add sent_to_email column
ALTER TABLE kshipra_core.user_referral_codes 
ADD COLUMN IF NOT EXISTS sent_to_email VARCHAR(255);

-- Add index for querying by sent email
CREATE INDEX IF NOT EXISTS idx_user_referral_codes_sent_email 
ON kshipra_core.user_referral_codes(sent_to_email) 
WHERE sent_to_email IS NOT NULL;

-- Update constraint: if email_sent is true, sent_to_email must be populated
ALTER TABLE kshipra_core.user_referral_codes
ADD CONSTRAINT check_email_sent_has_recipient 
CHECK (
    (email_sent = false AND sent_to_email IS NULL) OR
    (email_sent = true AND sent_to_email IS NOT NULL)
);

-- Add comment
COMMENT ON COLUMN kshipra_core.user_referral_codes.sent_to_email IS 'Email address this code was sent to (locked after first send)';
