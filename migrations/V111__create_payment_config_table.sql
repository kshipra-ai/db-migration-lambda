-- V111: Create payment_config table for managing monthly payment schedules
-- This table stores the configuration for automated monthly payments processing

CREATE TABLE IF NOT EXISTS kshipra_core.payment_config (
    id SERIAL PRIMARY KEY,
    google_ads_date INTEGER NOT NULL DEFAULT 15 CHECK (google_ads_date >= 1 AND google_ads_date <= 31),
    unity_ads_date INTEGER NOT NULL DEFAULT 20 CHECK (unity_ads_date >= 1 AND unity_ads_date <= 31),
    survey_date INTEGER NOT NULL DEFAULT 25 CHECK (survey_date >= 1 AND survey_date <= 31),
    google_ads_rate NUMERIC(10, 4) NOT NULL DEFAULT 0.0070 CHECK (google_ads_rate > 0),
    unity_ads_rate NUMERIC(10, 4) NOT NULL DEFAULT 0.0070 CHECK (unity_ads_rate > 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Insert default configuration
INSERT INTO kshipra_core.payment_config (google_ads_date, unity_ads_date, survey_date, google_ads_rate, unity_ads_rate)
VALUES (15, 20, 25, 0.0070, 0.0070)
ON CONFLICT (id) DO NOTHING;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_payment_config_id ON kshipra_core.payment_config(id);

-- Add comment
COMMENT ON TABLE kshipra_core.payment_config IS 'Configuration for automated monthly payment processing schedules and rates';
