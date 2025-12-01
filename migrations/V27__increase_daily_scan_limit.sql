-- V27: Increase daily scan limit for QR campaigns
-- This increases max_daily_scans from 10 to 1000 to allow more testing/usage

UPDATE kshipra_core.qr_campaigns
SET max_daily_scans = 1000
WHERE max_daily_scans < 1000;
