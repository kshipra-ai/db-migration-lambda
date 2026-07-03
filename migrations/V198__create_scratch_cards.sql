CREATE TABLE IF NOT EXISTS kshipra_core.scratch_cards (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             VARCHAR(255) NOT NULL,
    week_start          DATE NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | scratched
    reward_amount       NUMERIC(10,2) NOT NULL,
    commission_base     NUMERIC(10,2) NOT NULL,   -- total commission that week when card was issued
    trigger_action      VARCHAR(50) NOT NULL,      -- qr_scan | survey | ad
    triggered_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scratched_at        TIMESTAMPTZ,
    CONSTRAINT scratch_cards_status_check CHECK (status IN ('pending', 'scratched'))
);

CREATE INDEX IF NOT EXISTS idx_scratch_cards_user_status
    ON kshipra_core.scratch_cards (user_id, status);
