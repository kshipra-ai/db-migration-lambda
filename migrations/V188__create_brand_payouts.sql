-- V188: Create brand_payouts table for Tremendous-powered payouts
-- Tracks all payout requests (Interac manual + Tremendous automated)

CREATE TABLE IF NOT EXISTS kshipra_core.brand_payouts (
    payout_id           UUID         PRIMARY KEY,
    partner_id          TEXT         NOT NULL,
    brand_email         TEXT,
    company_name        TEXT,
    points_redeemed     INT          NOT NULL,
    cash_amount         NUMERIC(10,2) NOT NULL,
    payout_method       VARCHAR(50)  NOT NULL,
    payout_details      JSONB,
    tremendous_order_id VARCHAR(255),
    status              VARCHAR(50)  NOT NULL DEFAULT 'pending',
    payout_status       VARCHAR(50)  NOT NULL DEFAULT 'pending',
    requested_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_brand_payouts_partner_id
    ON kshipra_core.brand_payouts (partner_id);

CREATE INDEX IF NOT EXISTS idx_brand_payouts_status
    ON kshipra_core.brand_payouts (partner_id, status);

CREATE INDEX IF NOT EXISTS idx_brand_payouts_tremendous_order_id
    ON kshipra_core.brand_payouts (tremendous_order_id)
    WHERE tremendous_order_id IS NOT NULL;
