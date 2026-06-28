-- V190: Add Tremendous reward tracking fields to user_payouts
-- Enables: reward resend (needs reward_id), delivery failure tracking

ALTER TABLE kshipra_core.user_payouts
    ADD COLUMN IF NOT EXISTS tremendous_reward_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS failure_reason        TEXT,
    ADD COLUMN IF NOT EXISTS failed_at             TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_user_payouts_reward_id
    ON kshipra_core.user_payouts (tremendous_reward_id)
    WHERE tremendous_reward_id IS NOT NULL;
