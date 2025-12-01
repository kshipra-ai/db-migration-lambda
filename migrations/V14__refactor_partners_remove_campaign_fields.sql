-- V14__refactor_partners_remove_campaign_fields.sql
-- Remove campaign-specific fields from partners table
-- These fields belong in the campaigns table, not the partners table

-- Step 1: Remove campaign-specific columns from partners table
ALTER TABLE kshipra_core.partners 
DROP COLUMN IF EXISTS reward_rate,
DROP COLUMN IF EXISTS max_daily_rewards;

-- Step 2: Add company/brand specific fields that were missing
ALTER TABLE kshipra_core.partners 
ADD COLUMN IF NOT EXISTS company_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS website_url TEXT,
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS industry VARCHAR(100);

-- Step 3: Update existing brand_name to company_name if needed
UPDATE kshipra_core.partners 
SET company_name = brand_name 
WHERE company_name IS NULL;

-- Step 4: Make company_name NOT NULL after migration
ALTER TABLE kshipra_core.partners 
ALTER COLUMN company_name SET NOT NULL;

-- Step 5: Add index on company_name for search
CREATE INDEX IF NOT EXISTS idx_partners_company_name ON kshipra_core.partners(company_name);

-- Add comments
COMMENT ON COLUMN kshipra_core.partners.company_name IS 'Official company/brand name';
COMMENT ON COLUMN kshipra_core.partners.brand_slug IS 'URL-friendly identifier for the brand';
COMMENT ON COLUMN kshipra_core.partners.landing_url IS 'Main website or landing page URL';
COMMENT ON COLUMN kshipra_core.partners.website_url IS 'Company website URL';
COMMENT ON COLUMN kshipra_core.partners.logo_url IS 'URL to brand logo image';
COMMENT ON COLUMN kshipra_core.partners.contact_email IS 'Primary contact email for the partner';
COMMENT ON COLUMN kshipra_core.partners.description IS 'Description of the company/brand';
COMMENT ON COLUMN kshipra_core.partners.industry IS 'Industry sector (e.g., retail, food, technology)';

COMMENT ON TABLE kshipra_core.partners IS 'Partner companies/brands. Campaign-specific settings are in campaigns table.';
