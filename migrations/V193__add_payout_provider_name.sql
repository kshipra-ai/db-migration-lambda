-- Track which payout provider handled each row (tremendous, giftbit, etc.)
-- Existing rows default to 'tremendous' since that is the current provider.
ALTER TABLE kshipra_core.user_payouts
    ADD COLUMN IF NOT EXISTS provider_name VARCHAR(50) NOT NULL DEFAULT 'tremendous';
