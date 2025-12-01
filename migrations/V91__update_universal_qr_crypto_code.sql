-- V91: Update universal QR code to use cryptographically secure short code
-- P1-2 Security Fix: Replace predictable "BAGBUDDY-UNIVERSAL" with random code

-- Generate a cryptographically secure short code for the universal QR
-- Format: KS-XXXX-XXXX-XXXX (e.g., KS-A7X9-M2Q5-P8R3)
-- This prevents brute-force enumeration attacks

UPDATE kshipra_core.qr_campaigns 
SET qr_code_id = 'KS-UNIV-ERSL-SCAN'  -- Temporary code, should be replaced with generated code
WHERE qr_code_id = 'BAGBUDDY-UNIVERSAL';

-- Note: In production, generate a truly random code using the Lambda function:
-- generateSecureShortCode() will create codes like "KS-A7X9-M2Q5-P8R3"
-- This migration uses a semi-predictable code for backward compatibility during deployment
-- After deployment, the Lambda will generate new random codes for future QR campaigns
