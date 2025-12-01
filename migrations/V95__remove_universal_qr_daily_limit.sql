-- V95: Increase daily scan limit for universal QR code to 100
-- Universal QR is used for testing/demos and needs higher limit than individual campaign QRs

UPDATE kshipra_core.qr_campaigns
SET max_daily_scans = 100,
    updated_at = NOW()
WHERE qr_code_id = 'BAGBUDDY-UNIVERSAL';
