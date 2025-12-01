-- V93: Revert universal QR code back to BAGBUDDY-UNIVERSAL for printed QR codes
-- The cryptographic code from V91 broke existing printed QR codes

UPDATE kshipra_core.qr_campaigns
SET qr_code_id = 'BAGBUDDY-UNIVERSAL',
    updated_at = NOW()
WHERE qr_code_id = 'KS-UNIV-ERSL-SCAN'
   OR campaign_name = 'Universal QR - Campaign Rotation';

-- Ensure it's active
UPDATE kshipra_core.qr_campaigns
SET is_active = true,
    updated_at = NOW()
WHERE qr_code_id = 'BAGBUDDY-UNIVERSAL';
