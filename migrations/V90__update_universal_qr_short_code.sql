-- Update existing universal QR code_id to use short code format
UPDATE kshipra_core.qr_campaigns 
SET qr_code_id = 'BAGBUDDY-UNIVERSAL'
WHERE qr_code_id = 'universal-qr-bagbuddy';
