-- Insert universal QR code entry for BagBuddy campaign rotation
-- This QR code doesn't link to a specific campaign - the backend rotates campaigns dynamically

-- First, ensure BagBuddy system partner exists (generate a valid UUID)
INSERT INTO kshipra_core.partners (partner_id, brand_name, brand_slug, landing_url, contact_email, company_name, is_active)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'BagBuddy', 'bagbuddy', 'https://www.kshipraai.com', 'support@bagbuddy.com', 'BagBuddy Inc', true)
ON CONFLICT (partner_id) DO NOTHING;

-- Insert the universal QR campaign entry with simple short code
-- Use gen_random_uuid() to generate campaign_id
INSERT INTO kshipra_core.qr_campaigns 
(campaign_id, qr_code_id, partner_id, campaign_name, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'BAGBUDDY-UNIVERSAL',
    '00000000-0000-0000-0000-000000000001'::uuid,
    'Universal QR - Campaign Rotation',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (qr_code_id) DO UPDATE SET
    is_active = true,
    updated_at = NOW();
