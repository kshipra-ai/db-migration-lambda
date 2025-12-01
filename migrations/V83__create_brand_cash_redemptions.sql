-- Migration: Create brand_cash_redemptions table for tracking brand cash redemption requests
-- Version: V83
-- Description: Separate table for brand cash redemptions with monthly reporting structure

CREATE TABLE IF NOT EXISTS kshipra_core.brand_cash_redemptions (
    redemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    brand_email VARCHAR(255) NOT NULL,
    brand_name VARCHAR(255),
    company_name VARCHAR(255),
    points_redeemed INTEGER NOT NULL CHECK (points_redeemed > 0),
    cash_amount DECIMAL(10, 2) NOT NULL CHECK (cash_amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'rejected')),
    request_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    request_month VARCHAR(7),
    completion_date TIMESTAMP,
    completion_month VARCHAR(7),
    completed_by VARCHAR(255),
    admin_notes TEXT,
    payment_method VARCHAR(50),
    payment_reference VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance and reporting
CREATE INDEX idx_brand_cash_redemptions_partner ON kshipra_core.brand_cash_redemptions(partner_id);
CREATE INDEX idx_brand_cash_redemptions_status ON kshipra_core.brand_cash_redemptions(status);
CREATE INDEX idx_brand_cash_redemptions_request_date ON kshipra_core.brand_cash_redemptions(request_date DESC);
CREATE INDEX idx_brand_cash_redemptions_request_month ON kshipra_core.brand_cash_redemptions(request_month);
CREATE INDEX idx_brand_cash_redemptions_completion_month ON kshipra_core.brand_cash_redemptions(completion_month);

-- Trigger to auto-update timestamps and completion fields
CREATE OR REPLACE FUNCTION kshipra_core.update_brand_cash_redemption_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    NEW.request_month = TO_CHAR(NEW.request_date, 'YYYY-MM');
    
    IF NEW.status IN ('completed', 'rejected') AND OLD.status = 'pending' THEN
        NEW.completion_date = CURRENT_TIMESTAMP;
        NEW.completion_month = TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_brand_cash_redemption_timestamps
    BEFORE INSERT OR UPDATE ON kshipra_core.brand_cash_redemptions
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_brand_cash_redemption_timestamps();

-- Table and column comments for documentation
COMMENT ON TABLE kshipra_core.brand_cash_redemptions IS 'Tracks brand cash redemption requests with monthly reporting structure';
COMMENT ON COLUMN kshipra_core.brand_cash_redemptions.request_month IS 'Auto-generated YYYY-MM format for monthly reporting of requests';
COMMENT ON COLUMN kshipra_core.brand_cash_redemptions.completion_month IS 'Auto-generated YYYY-MM format for monthly reporting of completions';
