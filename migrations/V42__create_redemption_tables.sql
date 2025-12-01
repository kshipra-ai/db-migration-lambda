-- V41__create_redemption_tables.sql
-- Creates tables for the Points Redemption System
-- Safe migration: Only adds new tables, does not modify existing tables

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. USER BRAND ALLOCATIONS TABLE
-- Tracks redeemable points per user per brand
-- ============================================================
CREATE TABLE IF NOT EXISTS kshipra_core.user_brand_allocations (
    allocation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    max_redeemable_points INTEGER NOT NULL DEFAULT 0,
    total_points_redeemed INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_partner_allocation UNIQUE (user_id, partner_id)
);

-- Indexes for performance
CREATE INDEX idx_allocations_user ON kshipra_core.user_brand_allocations(user_id);
CREATE INDEX idx_allocations_partner ON kshipra_core.user_brand_allocations(partner_id);
CREATE INDEX idx_allocations_user_partner ON kshipra_core.user_brand_allocations(user_id, partner_id);

-- Comments
COMMENT ON TABLE kshipra_core.user_brand_allocations IS 'Tracks redeemable points per user per brand - enables brand-specific point redemption';
COMMENT ON COLUMN kshipra_core.user_brand_allocations.max_redeemable_points IS 'Total points user can redeem at this brand (cumulative earnings)';
COMMENT ON COLUMN kshipra_core.user_brand_allocations.total_points_redeemed IS 'Historical total of points already redeemed at this brand';

-- ============================================================
-- 2. REDEMPTIONS TABLE
-- One-time redemption QR codes for users to redeem points
-- ============================================================
CREATE TABLE IF NOT EXISTS kshipra_core.redemptions (
    redemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    qr_token VARCHAR(255) UNIQUE NOT NULL,
    points_redeemed INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    scanned_at TIMESTAMPTZ,
    scanned_by_user_id TEXT REFERENCES kshipra_core.user_profile(user_id),
    invalid_scan_attempts INTEGER NOT NULL DEFAULT 0,
    metadata JSONB,
    CONSTRAINT chk_redemption_status CHECK (status IN ('pending', 'scanned', 'expired')),
    CONSTRAINT chk_redemption_points_min CHECK (points_redeemed >= 100),
    CONSTRAINT chk_redemption_points_positive CHECK (points_redeemed > 0)
);

-- Indexes for performance
CREATE INDEX idx_redemptions_user ON kshipra_core.redemptions(user_id);
CREATE INDEX idx_redemptions_partner ON kshipra_core.redemptions(partner_id);
CREATE INDEX idx_redemptions_qr_token ON kshipra_core.redemptions(qr_token);
CREATE INDEX idx_redemptions_status ON kshipra_core.redemptions(status);
CREATE INDEX idx_redemptions_expires_at ON kshipra_core.redemptions(expires_at);
CREATE INDEX idx_redemptions_user_status ON kshipra_core.redemptions(user_id, status);
CREATE INDEX idx_redemptions_partner_status ON kshipra_core.redemptions(partner_id, status);
CREATE INDEX idx_redemptions_created_at ON kshipra_core.redemptions(created_at DESC);

-- Comments
COMMENT ON TABLE kshipra_core.redemptions IS 'One-time use QR codes for users to redeem points at brand stores';
COMMENT ON COLUMN kshipra_core.redemptions.qr_token IS 'Cryptographically secure random token embedded in QR code';
COMMENT ON COLUMN kshipra_core.redemptions.status IS 'pending: Not yet scanned, scanned: Successfully redeemed, expired: Past expiry date';
COMMENT ON COLUMN kshipra_core.redemptions.expires_at IS 'QR code expires 60 days after creation';
COMMENT ON COLUMN kshipra_core.redemptions.scanned_by_user_id IS 'Brand user who scanned and validated the QR code';

-- ============================================================
-- 3. BRAND CREDITS TABLE
-- Credits owed to brands from user redemptions
-- ============================================================
CREATE TABLE IF NOT EXISTS kshipra_core.brand_credits (
    credit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    redemption_id UUID NOT NULL REFERENCES kshipra_core.redemptions(redemption_id) ON DELETE CASCADE,
    points_credited INTEGER NOT NULL,
    billing_month VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    billing_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    invoice_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_credit_billing_status CHECK (billing_status IN ('pending', 'invoiced', 'paid')),
    CONSTRAINT chk_credit_points_positive CHECK (points_credited > 0),
    CONSTRAINT chk_billing_month_format CHECK (billing_month ~ '^\d{4}-\d{2}$')
);

-- Indexes for performance
CREATE INDEX idx_credits_partner ON kshipra_core.brand_credits(partner_id);
CREATE INDEX idx_credits_billing_month ON kshipra_core.brand_credits(billing_month);
CREATE INDEX idx_credits_billing_status ON kshipra_core.brand_credits(billing_status);
CREATE INDEX idx_credits_partner_month ON kshipra_core.brand_credits(partner_id, billing_month);
CREATE INDEX idx_credits_redemption ON kshipra_core.brand_credits(redemption_id);

-- Comments
COMMENT ON TABLE kshipra_core.brand_credits IS 'Credits owed to brands from user redemptions - used for monthly invoicing';
COMMENT ON COLUMN kshipra_core.brand_credits.billing_month IS 'Month when credit should be invoiced (YYYY-MM format)';
COMMENT ON COLUMN kshipra_core.brand_credits.billing_status IS 'pending: Not invoiced, invoiced: Invoice generated, paid: Payment received';

-- ============================================================
-- 4. INVOICES TABLE
-- Monthly invoices for brands
-- ============================================================
CREATE TABLE IF NOT EXISTS kshipra_core.invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    billing_month VARCHAR(7) NOT NULL,
    total_points_redeemed INTEGER NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    invoice_status VARCHAR(20) NOT NULL DEFAULT 'generated',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    invoice_url VARCHAR(500),
    metadata JSONB,
    CONSTRAINT chk_invoice_status CHECK (invoice_status IN ('generated', 'sent', 'paid', 'cancelled')),
    CONSTRAINT chk_invoice_amount_positive CHECK (total_amount >= 0),
    CONSTRAINT chk_invoice_points_positive CHECK (total_points_redeemed >= 0),
    CONSTRAINT chk_invoice_billing_month_format CHECK (billing_month ~ '^\d{4}-\d{2}$'),
    CONSTRAINT unique_partner_billing_month UNIQUE (partner_id, billing_month)
);

-- Indexes for performance
CREATE INDEX idx_invoices_partner ON kshipra_core.invoices(partner_id);
CREATE INDEX idx_invoices_billing_month ON kshipra_core.invoices(billing_month);
CREATE INDEX idx_invoices_status ON kshipra_core.invoices(invoice_status);
CREATE INDEX idx_invoices_invoice_number ON kshipra_core.invoices(invoice_number);
CREATE INDEX idx_invoices_generated_at ON kshipra_core.invoices(generated_at DESC);

-- Comments
COMMENT ON TABLE kshipra_core.invoices IS 'Monthly invoices for brands based on user redemptions';
COMMENT ON COLUMN kshipra_core.invoices.invoice_number IS 'Unique invoice number in format: INV-YYYY-MM-BRANDSLUG';
COMMENT ON COLUMN kshipra_core.invoices.total_amount IS 'Amount in USD (or configured currency)';
COMMENT ON COLUMN kshipra_core.invoices.due_date IS 'Payment due date (typically 30 days after generation)';
COMMENT ON COLUMN kshipra_core.invoices.invoice_url IS 'S3 URL to PDF invoice document';

-- Add foreign key constraint for invoice_id in brand_credits (after invoices table exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_brand_credits_invoice'
    ) THEN
        ALTER TABLE kshipra_core.brand_credits 
        ADD CONSTRAINT fk_brand_credits_invoice 
        FOREIGN KEY (invoice_id) REFERENCES kshipra_core.invoices(invoice_id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================================
-- 5. REDEMPTION SCAN LOGS TABLE
-- Security and audit log of all scan attempts
-- ============================================================
CREATE TABLE IF NOT EXISTS kshipra_core.redemption_scan_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    redemption_id UUID REFERENCES kshipra_core.redemptions(redemption_id),
    qr_token VARCHAR(255),
    scanned_by_user_id TEXT REFERENCES kshipra_core.user_profile(user_id),
    scanned_by_partner_id UUID REFERENCES kshipra_core.partners(partner_id),
    scan_result VARCHAR(20) NOT NULL,
    error_message TEXT,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    device_info JSONB,
    CONSTRAINT chk_scan_result CHECK (scan_result IN (
        'success',
        'invalid_brand',
        'already_used',
        'expired',
        'not_found',
        'insufficient_points',
        'invalid_token',
        'user_not_found',
        'brand_not_found',
        'invalid_signature'
    ))
);

-- Indexes for performance
CREATE INDEX idx_scan_logs_redemption ON kshipra_core.redemption_scan_logs(redemption_id);
CREATE INDEX idx_scan_logs_user ON kshipra_core.redemption_scan_logs(scanned_by_user_id);
CREATE INDEX idx_scan_logs_partner ON kshipra_core.redemption_scan_logs(scanned_by_partner_id);
CREATE INDEX idx_scan_logs_result ON kshipra_core.redemption_scan_logs(scan_result);
CREATE INDEX idx_scan_logs_scanned_at ON kshipra_core.redemption_scan_logs(scanned_at DESC);

-- Comments
COMMENT ON TABLE kshipra_core.redemption_scan_logs IS 'Audit log of all redemption QR code scan attempts (success and failures)';
COMMENT ON COLUMN kshipra_core.redemption_scan_logs.scan_result IS 'Outcome of scan attempt - used for security monitoring and fraud detection';
COMMENT ON COLUMN kshipra_core.redemption_scan_logs.device_info IS 'Optional device information for security analysis';

-- ============================================================
-- 6. HELPER FUNCTIONS
-- ============================================================

-- Function to calculate available redeemable points for a user at a brand
CREATE OR REPLACE FUNCTION kshipra_core.get_available_redeemable_points(
    p_user_id TEXT,
    p_partner_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_max_redeemable INTEGER := 0;
    v_total_redeemed INTEGER := 0;
BEGIN
    SELECT 
        COALESCE(max_redeemable_points, 0),
        COALESCE(total_points_redeemed, 0)
    INTO v_max_redeemable, v_total_redeemed
    FROM kshipra_core.user_brand_allocations
    WHERE user_id = p_user_id AND partner_id = p_partner_id;
    
    -- Also subtract any pending (not yet scanned) redemptions
    SELECT COALESCE(SUM(points_redeemed), 0)
    INTO v_total_redeemed
    FROM (
        SELECT total_points_redeemed FROM kshipra_core.user_brand_allocations
        WHERE user_id = p_user_id AND partner_id = p_partner_id
        UNION ALL
        SELECT COALESCE(SUM(points_redeemed), 0) FROM kshipra_core.redemptions
        WHERE user_id = p_user_id 
          AND partner_id = p_partner_id 
          AND status = 'pending'
          AND expires_at > now()
    ) AS combined;
    
    RETURN GREATEST(v_max_redeemable - v_total_redeemed, 0);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION kshipra_core.get_available_redeemable_points IS 'Calculate remaining redeemable points for user at specific brand (includes pending redemptions)';

-- Function to mark expired redemptions
CREATE OR REPLACE FUNCTION kshipra_core.mark_expired_redemptions()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE kshipra_core.redemptions
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at <= now();
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION kshipra_core.mark_expired_redemptions IS 'Marks all pending redemptions past expiry date as expired - run periodically';

-- ============================================================
-- 7. GRANT PERMISSIONS
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.user_brand_allocations TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.redemptions TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.brand_credits TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.invoices TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.redemption_scan_logs TO kshipra_admin;

GRANT EXECUTE ON FUNCTION kshipra_core.get_available_redeemable_points TO kshipra_admin;
GRANT EXECUTE ON FUNCTION kshipra_core.mark_expired_redemptions TO kshipra_admin;

-- ============================================================
-- 8. VERIFICATION
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE 'Redemption tables created successfully!';
    RAISE NOTICE '   - user_brand_allocations';
    RAISE NOTICE '   - redemptions';
    RAISE NOTICE '   - brand_credits';
    RAISE NOTICE '   - invoices';
    RAISE NOTICE '   - redemption_scan_logs';
    RAISE NOTICE 'Helper functions created';
    RAISE NOTICE 'All indexes and constraints added';
END $$;
