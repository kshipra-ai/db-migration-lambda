-- V98: Clean up auto-created Nike and Eco Market campaigns, create Kshipra default campaign

-- Delete the auto-created Nike and Eco Market welcome campaigns
DELETE FROM kshipra_core.campaigns 
WHERE campaign_name IN ('Nike Store - Welcome Campaign', 'Eco Market - Welcome Campaign');

-- Create Kshipra Universal partner if it doesn't exist
INSERT INTO kshipra_core.partners 
(partner_id, brand_name, brand_slug, landing_url, contact_email, company_name, is_active)
VALUES (
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Kshipra Universal',
    'kshipra-universal',
    'https://www.kshipraai.com',
    'info@kshipraai.com',
    'Kshipra AI Inc',
    true
)
ON CONFLICT (partner_id) DO UPDATE 
SET brand_name = EXCLUDED.brand_name,
    landing_url = EXCLUDED.landing_url;

-- Create the default Kshipra campaign
INSERT INTO kshipra_core.campaigns 
(partner_id, campaign_name, campaign_description, landing_url, reward_rate, max_daily_rewards, is_active)
SELECT
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Kshipra Default Campaign',
    'Default campaign - learn more about sustainable shopping with Kshipra',
    'https://www.kshipraai.com',
    10,
    10,
    true
WHERE NOT EXISTS (
    SELECT 1 FROM kshipra_core.campaigns 
    WHERE campaign_name = 'Kshipra Default Campaign'
);
