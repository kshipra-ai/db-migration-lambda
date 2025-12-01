-- V85: Force delete all pending brand cash redemptions for testing cleanup
DELETE FROM kshipra_core.brand_cash_redemptions
WHERE status = 'pending';
