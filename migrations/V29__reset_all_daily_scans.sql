-- V29: Reset daily scan count for all users
-- Clear all today's scans to allow testing

DELETE FROM kshipra_core.qr_scans 
WHERE DATE(scanned_at) = CURRENT_DATE;
