-- Migration: Add max_email_resends configuration to referral system
-- This allows admins to configure the maximum number of email resends per referral code

-- Update the referral_system configuration to include max_email_resends
UPDATE kshipra_core.system_configurations
SET config_value = jsonb_set(
    config_value,
    '{max_email_resends}',
    '3'::jsonb
)
WHERE config_key = 'referral_system';

-- Update description to mention the new field
UPDATE kshipra_core.system_configurations
SET description = 'Referral system configuration including rewards, limits, email resend limits, and feature toggles'
WHERE config_key = 'referral_system';
