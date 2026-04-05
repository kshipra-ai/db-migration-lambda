-- V147__create_announcements_table.sql
-- Admin-managed dashboard banners for users and brands
-- Max 3 enabled at a time per audience, enforced in application layer

CREATE TABLE kshipra_core.announcements (
    announcement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(100) NOT NULL,
    description VARCHAR(300) NOT NULL,
    target_audience VARCHAR(10) NOT NULL CHECK (target_audience IN ('user', 'brand', 'both')),
    is_enabled BOOLEAN NOT NULL DEFAULT false,
    display_order INT NOT NULL DEFAULT 0,
    emoji VARCHAR(10) DEFAULT '📢',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_announcements_enabled_audience
ON kshipra_core.announcements (is_enabled, target_audience);
