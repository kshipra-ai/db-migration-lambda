-- Migration: Create user_monthly_ads_summary table for monthly ads payment tracking
-- Version: V110
-- Date: 2026-01-09
-- Description: Track total number of ads watched per user per month for end-of-month payment
--              IMPORTANT: Ads DO NOT update pending_balance (only surveys do that)
--              Ads payment is calculated monthly and added directly to cash_balance

-- Create table for monthly ads summary
CREATE TABLE IF NOT EXISTS kshipra_core.user_monthly_ads_summary (
    summary_id UUID DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    google_ads_count INTEGER DEFAULT 0,
    unity_ads_count INTEGER DEFAULT 0,
    ironsource_ads_count INTEGER DEFAULT 0,
    total_ads_count INTEGER GENERATED ALWAYS AS (
        COALESCE(google_ads_count, 0) + 
        COALESCE(unity_ads_count, 0) + 
        COALESCE(ironsource_ads_count, 0)
    ) STORED,
    estimated_payment DECIMAL(10, 4) DEFAULT 0.00,
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'processing', 'paid', 'cancelled')),
    payment_date TIMESTAMP,
    payment_amount DECIMAL(10, 4),
    payment_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_monthly_ads_summary PRIMARY KEY (user_id, month_year),
    CONSTRAINT fk_user_monthly_ads_user
        FOREIGN KEY (user_id) 
        REFERENCES kshipra_core.user_profile(user_id)
        ON DELETE CASCADE
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_monthly_ads_month 
ON kshipra_core.user_monthly_ads_summary(month_year);

CREATE INDEX IF NOT EXISTS idx_monthly_ads_payment_status 
ON kshipra_core.user_monthly_ads_summary(payment_status);

CREATE INDEX IF NOT EXISTS idx_monthly_ads_user_status 
ON kshipra_core.user_monthly_ads_summary(user_id, payment_status);

-- Add comments
COMMENT ON TABLE kshipra_core.user_monthly_ads_summary IS 'Monthly summary of ads watched per user for payment calculation - does NOT use pending_balance';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.month_year IS 'Month in YYYY-MM format';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.google_ads_count IS 'Total Google ads watched this month';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.unity_ads_count IS 'Total Unity ads watched this month';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.ironsource_ads_count IS 'Total IronSource ads watched this month';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.total_ads_count IS 'Total ads watched (all providers)';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.estimated_payment IS 'Estimated payment for reference only (not added to pending_balance)';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.payment_status IS 'Status: pending, processing, paid, cancelled';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.payment_date IS 'When payment was processed';
COMMENT ON COLUMN kshipra_core.user_monthly_ads_summary.payment_amount IS 'Actual amount paid - added directly to cash_balance';

-- Create function to update monthly summary
CREATE OR REPLACE FUNCTION kshipra_core.update_monthly_ads_summary()
RETURNS TRIGGER AS $$
DECLARE
    current_month VARCHAR(7);
BEGIN
    -- Get current month in YYYY-MM format
    current_month := TO_CHAR(NEW.view_date, 'YYYY-MM');
    
    -- Insert or update monthly summary
    INSERT INTO kshipra_core.user_monthly_ads_summary (
        user_id, 
        month_year, 
        google_ads_count, 
        unity_ads_count, 
        ironsource_ads_count,
        updated_at
    ) VALUES (
        NEW.user_id,
        current_month,
        COALESCE(NEW.ad_count, 0),
        COALESCE(NEW.unity_ad_count, 0),
        COALESCE(NEW.ironsource_ad_count, 0),
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (user_id, month_year) 
    DO UPDATE SET
        google_ads_count = kshipra_core.user_monthly_ads_summary.google_ads_count + 
                          (COALESCE(NEW.ad_count, 0) - COALESCE(OLD.ad_count, 0)),
        unity_ads_count = kshipra_core.user_monthly_ads_summary.unity_ads_count + 
                         (COALESCE(NEW.unity_ad_count, 0) - COALESCE(OLD.unity_ad_count, 0)),
        ironsource_ads_count = kshipra_core.user_monthly_ads_summary.ironsource_ads_count + 
                              (COALESCE(NEW.ironsource_ad_count, 0) - COALESCE(OLD.ironsource_ad_count, 0)),
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update monthly summary
DROP TRIGGER IF EXISTS trg_update_monthly_ads_summary ON kshipra_core.user_daily_ad_views;
CREATE TRIGGER trg_update_monthly_ads_summary
    AFTER INSERT OR UPDATE ON kshipra_core.user_daily_ad_views
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_monthly_ads_summary();

-- Add system configuration for monthly payment rates
INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, is_active, created_at, updated_at)
VALUES 
  ('monthly_ad_payment_rates', '{"google_avg_cpm": 7.00, "unity_avg_cpm": 7.00, "ironsource_avg_cpm": 6.00, "per_1000_views": true}', 
   'Average payment rates per 1000 ad views for monthly payment calculation', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (config_key) 
DO UPDATE SET 
    config_value = EXCLUDED.config_value,
    updated_at = CURRENT_TIMESTAMP;

-- Verify the migration
SELECT 
    'user_monthly_ads_summary table created' as status,
    COUNT(*) as record_count
FROM kshipra_core.user_monthly_ads_summary;

SELECT config_key, config_value 
FROM kshipra_core.system_configurations 
WHERE config_key = 'monthly_ad_payment_rates';
