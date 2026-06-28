CREATE TABLE IF NOT EXISTS kshipra_core.payout_method_config (
    method      VARCHAR(20)    PRIMARY KEY,
    enabled     BOOLEAN        NOT NULL DEFAULT true,
    min_amount  NUMERIC(10,2)  NOT NULL DEFAULT 5.00,
    updated_at  TIMESTAMP      NOT NULL DEFAULT NOW(),
    updated_by  VARCHAR(255)
);

INSERT INTO kshipra_core.payout_method_config (method, enabled, min_amount) VALUES
    ('interac',  true, 5.00),
    ('paypal',   true, 5.00),
    ('giftcard', true, 20.00)
ON CONFLICT (method) DO NOTHING;
