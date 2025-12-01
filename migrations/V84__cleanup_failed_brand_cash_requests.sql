-- V84: Clean up failed brand cash redemption test records
DELETE FROM kshipra_core.brand_cash_redemptions
WHERE status = 'pending'
AND completion_date IS NULL;
