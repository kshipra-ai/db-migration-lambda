CREATE TABLE IF NOT EXISTS kshipra_core.scratch_card_config (
    id                  SERIAL PRIMARY KEY,
    enabled             BOOLEAN NOT NULL DEFAULT false,
    actions_threshold   INT NOT NULL DEFAULT 5,
    commission_pct      NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Single config row
INSERT INTO kshipra_core.scratch_card_config (enabled, actions_threshold, commission_pct)
VALUES (false, 5, 10.00)
ON CONFLICT DO NOTHING;
