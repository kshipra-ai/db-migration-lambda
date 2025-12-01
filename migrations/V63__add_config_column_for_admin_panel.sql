-- Migration: Add config column to user_profile and partners tables for admin panel
-- This allows storing custom JSON configurations per user/brand (e.g., blocking, custom settings)

-- Add config column to user_profile table
ALTER TABLE kshipra_core.user_profile 
ADD COLUMN IF NOT EXISTS config JSONB DEFAULT '{}'::jsonb;

-- Add config column to partners table
ALTER TABLE kshipra_core.partners 
ADD COLUMN IF NOT EXISTS config JSONB DEFAULT '{}'::jsonb;

-- Add GIN indexes for better performance when querying JSON config
CREATE INDEX IF NOT EXISTS idx_user_profile_config ON kshipra_core.user_profile USING gin(config);
CREATE INDEX IF NOT EXISTS idx_partners_config ON kshipra_core.partners USING gin(config);

-- Grant necessary permissions
GRANT SELECT, UPDATE ON kshipra_core.user_profile TO kshipra_admin;
GRANT SELECT, UPDATE ON kshipra_core.partners TO kshipra_admin;
