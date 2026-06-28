-- V187: Add payout method support to brand_cash_redemptions
-- Enables Tremendous-powered payouts (PayPal, Venmo, gift cards, ACH)
-- alongside the existing manual Interac e-Transfer flow.

ALTER TABLE kshipra_core.brand_cash_redemptions
    ADD COLUMN IF NOT EXISTS payout_method       VARCHAR(50)  NOT NULL DEFAULT 'interac',
    ADD COLUMN IF NOT EXISTS payout_details      JSONB,
    ADD COLUMN IF NOT EXISTS tremendous_order_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS payout_status       VARCHAR(50)  NOT NULL DEFAULT 'pending';

-- payout_method: 'interac' | 'paypal' | 'venmo' | 'ach' | 'giftcard'
-- payout_details: method-specific JSON e.g. {"email": "user@paypal.com"} or {"phone": "+16135551234"}
-- tremendous_order_id: populated when Tremendous processes the payout automatically
-- payout_status: 'pending' | 'processing' | 'completed' | 'failed'

CREATE INDEX IF NOT EXISTS idx_bcr_payout_method
    ON kshipra_core.brand_cash_redemptions (payout_method);

CREATE INDEX IF NOT EXISTS idx_bcr_tremendous_order_id
    ON kshipra_core.brand_cash_redemptions (tremendous_order_id)
    WHERE tremendous_order_id IS NOT NULL;
