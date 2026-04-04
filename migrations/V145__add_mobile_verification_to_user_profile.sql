-- V145: Add mobile verification fields to user_profile
-- Mobile verification is required to complete the user profile.
-- One phone number may only be verified on one account at a time.

ALTER TABLE kshipra_core.user_profile
ADD COLUMN IF NOT EXISTS mobile_verified BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS mobile_otp_code   VARCHAR(10),
ADD COLUMN IF NOT EXISTS mobile_otp_expires_at TIMESTAMP WITH TIME ZONE;

-- Partial unique index: enforce one account per verified mobile number
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profile_unique_verified_phone
    ON kshipra_core.user_profile (phone_number)
    WHERE mobile_verified = TRUE AND is_deleted = FALSE;

-- Index for fast OTP lookups during verification
CREATE INDEX IF NOT EXISTS idx_user_profile_mobile_otp
    ON kshipra_core.user_profile (user_id, mobile_otp_expires_at)
    WHERE mobile_otp_code IS NOT NULL;

COMMENT ON COLUMN kshipra_core.user_profile.mobile_verified IS
'TRUE once the user has confirmed ownership of their phone number via OTP.';
COMMENT ON COLUMN kshipra_core.user_profile.mobile_otp_code IS
'Temporary 6-digit OTP sent to the users phone. Cleared after successful verification.';
COMMENT ON COLUMN kshipra_core.user_profile.mobile_otp_expires_at IS
'UTC expiry time for the OTP (10 minutes from issue). Cleared after successful verification.';
