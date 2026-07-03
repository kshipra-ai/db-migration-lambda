INSERT INTO kshipra_core.payout_method_config (method, enabled, min_amount) VALUES
    ('walmart',    true, 10.00),
    ('apple',      true, 15.00),
    ('petrocan',   true, 10.00),
    ('rexall',     true, 10.00),
    ('googleplay', true, 10.00)
ON CONFLICT (method) DO NOTHING;
