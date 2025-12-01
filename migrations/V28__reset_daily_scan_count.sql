-- V28: Reset daily scan count for testing
-- This is a one-time cleanup to allow continued testing

DELETE FROM kshipra_core.qr_scans 
WHERE user_id = '110972166747922284242' 
AND DATE(scanned_at) = CURRENT_DATE;
