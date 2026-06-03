-- V179: Add Apple private relay email support
-- is_private_relay_email: true when user signed in with Apple "Hide My Email"
-- notification_email: real email provided by user for SES comms and survey targeting

ALTER TABLE kshipra_core.user_profile
    ADD COLUMN IF NOT EXISTS is_private_relay_email BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS notification_email VARCHAR(255) DEFAULT NULL;

COMMENT ON COLUMN kshipra_core.user_profile.is_private_relay_email
    IS 'True when the account email is an Apple private relay address (@privaterelay.appleid.com)';

COMMENT ON COLUMN kshipra_core.user_profile.notification_email
    IS 'Real email provided by user for SES notifications and survey targeting when using Apple Hide My Email';

CREATE INDEX IF NOT EXISTS idx_user_profile_notification_email
    ON kshipra_core.user_profile(notification_email)
    WHERE notification_email IS NOT NULL;
