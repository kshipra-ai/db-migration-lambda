-- V137: Add interac_email column to user_profile
-- Allows users to set a separate Interac e-Transfer email for cash payouts.
-- NULL means use the registered email.

ALTER TABLE kshipra_core.user_profile
    ADD COLUMN IF NOT EXISTS interac_email VARCHAR(255) DEFAULT NULL;

COMMENT ON COLUMN kshipra_core.user_profile.interac_email
    IS 'Optional Interac e-Transfer email for cash payouts. If NULL, registered email is used.';
