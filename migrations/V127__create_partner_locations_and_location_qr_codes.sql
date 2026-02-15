-- V127: Create partner_locations and location_qr_codes tables
-- Supports restaurant-specific QR codes for table-level tracking and billing
-- These tables are purely additive — no existing tables or code are modified

-- ============================================
-- 1. partner_locations — one row per restaurant/store location
-- ============================================
CREATE TABLE IF NOT EXISTS kshipra_core.partner_locations (
    location_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id          UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    location_name       VARCHAR(255) NOT NULL,
    address             TEXT,
    city                VARCHAR(100),
    province            VARCHAR(100),
    postal_code         VARCHAR(20),
    country             VARCHAR(100) DEFAULT 'Canada',
    contact_name        VARCHAR(255),
    contact_email       VARCHAR(255),
    contact_phone       VARCHAR(50),
    table_count         INTEGER NOT NULL DEFAULT 0,
    monthly_rate_cents  INTEGER NOT NULL DEFAULT 0,
    billing_start_date  DATE,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookups by partner
CREATE INDEX IF NOT EXISTS idx_partner_locations_partner_id
    ON kshipra_core.partner_locations(partner_id);

CREATE INDEX IF NOT EXISTS idx_partner_locations_active
    ON kshipra_core.partner_locations(partner_id, is_active);

-- ============================================
-- 2. location_qr_codes — maps qr_code_id to a location + table
-- ============================================
CREATE TABLE IF NOT EXISTS kshipra_core.location_qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id     UUID NOT NULL REFERENCES kshipra_core.partner_locations(location_id) ON DELETE CASCADE,
    qr_code_id      VARCHAR(100) NOT NULL UNIQUE,
    table_label     VARCHAR(50),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for joining with qr_scans on qr_code_id
CREATE INDEX IF NOT EXISTS idx_location_qr_codes_qr_code_id
    ON kshipra_core.location_qr_codes(qr_code_id);

CREATE INDEX IF NOT EXISTS idx_location_qr_codes_location_id
    ON kshipra_core.location_qr_codes(location_id);
