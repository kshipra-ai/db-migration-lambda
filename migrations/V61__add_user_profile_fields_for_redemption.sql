-- V61: Add user profile fields required for cashback redemption
-- Users must provide name, gender, location, and verified email before redeeming

-- Add profile completion columns
ALTER TABLE kshipra_core.user_profile
ADD COLUMN IF NOT EXISTS full_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS gender VARCHAR(20),
ADD COLUMN IF NOT EXISTS location VARCHAR(255),
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20),
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;

-- Create index for faster profile completion checks
CREATE INDEX IF NOT EXISTS idx_user_profile_completed ON kshipra_core.user_profile(profile_completed);

-- Comment on new columns
COMMENT ON COLUMN kshipra_core.user_profile.full_name IS 'User full name required for cashback';
COMMENT ON COLUMN kshipra_core.user_profile.gender IS 'User gender (male, female, other, prefer_not_to_say)';
COMMENT ON COLUMN kshipra_core.user_profile.location IS 'User location/city for cashback processing';
COMMENT ON COLUMN kshipra_core.user_profile.email_verified IS 'Whether email has been verified';
COMMENT ON COLUMN kshipra_core.user_profile.phone_number IS 'Optional phone number for contact';
COMMENT ON COLUMN kshipra_core.user_profile.profile_completed IS 'Whether user has completed all required profile fields for redemption';
