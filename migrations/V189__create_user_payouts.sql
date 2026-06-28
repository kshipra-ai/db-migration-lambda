-- V189: Create user_payouts table for user cash-out requests
-- Supports Interac (manual) + Tremendous automated methods (PayPal, Venmo, ACH, gift cards)

CREATE TABLE IF NOT EXISTS kshipra_core.user_payouts (
    payout_id           UUID         PRIMARY KEY,
    user_id             TEXT         NOT NULL,
    user_email          TEXT,
    user_name           TEXT,
    cash_amount         NUMERIC(10,2) NOT NULL,
    payout_method       VARCHAR(50)  NOT NULL,
    payout_details      JSONB,
    tremendous_order_id VARCHAR(255),
    status              VARCHAR(50)  NOT NULL DEFAULT 'pending',
    payout_status       VARCHAR(50)  NOT NULL DEFAULT 'pending',
    requested_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_payouts_user_id
    ON kshipra_core.user_payouts (user_id);

CREATE INDEX IF NOT EXISTS idx_user_payouts_status
    ON kshipra_core.user_payouts (user_id, status);

CREATE INDEX IF NOT EXISTS idx_user_payouts_tremendous_order_id
    ON kshipra_core.user_payouts (tremendous_order_id)
    WHERE tremendous_order_id IS NOT NULL;
