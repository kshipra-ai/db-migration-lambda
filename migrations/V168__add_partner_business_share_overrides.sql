-- V168: Add per-business QR host share overrides.
-- Global reward_distribution_config remains the default. A partner-specific
-- override only changes the business share; Kshipra receives the remaining
-- scan reward after user rewards, cashback, and business share.

CREATE TABLE IF NOT EXISTS kshipra_core.partner_reward_share_config (
    config_id SERIAL PRIMARY KEY,
    partner_id UUID NOT NULL REFERENCES kshipra_core.partners(partner_id) ON DELETE CASCADE,
    business_share_percentage NUMERIC(5,2) NOT NULL
        CHECK (business_share_percentage >= 0 AND business_share_percentage <= 100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_reward_share_one_active
    ON kshipra_core.partner_reward_share_config(partner_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_partner_reward_share_partner
    ON kshipra_core.partner_reward_share_config(partner_id, is_active, effective_from DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.partner_reward_share_config TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.partner_reward_share_config_config_id_seq TO kshipra_admin;

DROP FUNCTION IF EXISTS kshipra_core.complete_deep_link_view_session(VARCHAR, UUID, INTEGER);

CREATE OR REPLACE FUNCTION kshipra_core.complete_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_actual_duration_seconds INTEGER
)
RETURNS TABLE(
    is_completed BOOLEAN,
    points_awarded INTEGER,
    user_rewards_points INTEGER,
    cashback_cents INTEGER,
    total_user_points INTEGER
) AS $$
DECLARE
    v_required_duration INTEGER;
    v_is_completed BOOLEAN := FALSE;
    v_already_completed BOOLEAN := FALSE;
    v_reward_rate INTEGER;
    v_scan_reward_points INTEGER;
    v_points_awarded INTEGER := 0;
    v_partner_id UUID;
    v_total_points INTEGER := 0;
    v_location_id UUID;
    v_qr_code_id VARCHAR(255);
    v_business_user_id TEXT;
    v_business_partner_id UUID;

    v_user_rewards_pct DECIMAL(5,2);
    v_cashback_pct DECIMAL(5,2);
    v_kshipra_commission_pct DECIMAL(5,2);
    v_business_share_pct DECIMAL(5,2);
    v_override_business_share_pct DECIMAL(5,2);
    v_max_business_share_pct DECIMAL(5,2);
    v_user_rewards_cents INTEGER := 0;
    v_cashback_cents INTEGER := 0;
    v_kshipra_commission_cents INTEGER := 0;
    v_business_share_cents INTEGER := 0;
BEGIN
    SELECT COALESCE(udlv.is_completed, false)
    INTO v_already_completed
    FROM kshipra_core.user_deep_link_views udlv
    WHERE udlv.user_id::VARCHAR = p_user_id
      AND udlv.campaign_id = p_campaign_id;

    IF v_already_completed THEN
        SELECT COALESCE(up.rewards_earned, 0)
        INTO v_total_points
        FROM kshipra_core.user_profile up
        WHERE up.user_id::VARCHAR = p_user_id;

        RETURN QUERY SELECT false, 0, 0, 0, v_total_points;
        RETURN;
    END IF;

    SELECT
        c.min_view_duration_seconds,
        c.reward_rate,
        c.partner_id,
        COALESCE((p.config->>'scan_reward_points')::INTEGER, c.reward_rate) as scan_points
    INTO
        v_required_duration,
        v_reward_rate,
        v_partner_id,
        v_scan_reward_points
    FROM kshipra_core.campaigns c
    LEFT JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
    WHERE c.campaign_id = p_campaign_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    v_required_duration := COALESCE(v_required_duration, 10);

    SELECT qs.location_id, qs.qr_code_id
    INTO v_location_id, v_qr_code_id
    FROM kshipra_core.qr_scans qs
    WHERE qs.user_id::VARCHAR = p_user_id
      AND qs.campaign_id = p_campaign_id
      AND qs.scanned_at >= CURRENT_DATE
    ORDER BY qs.scanned_at DESC
    LIMIT 1;

    IF v_location_id IS NOT NULL THEN
        SELECT p.user_id, p.partner_id
        INTO v_business_user_id, v_business_partner_id
        FROM kshipra_core.partner_locations pl
        JOIN kshipra_core.partners p ON p.partner_id = pl.partner_id
        WHERE pl.location_id = v_location_id
          AND pl.is_active = TRUE
          AND p.is_active = TRUE
        LIMIT 1;
    END IF;

    IF p_actual_duration_seconds >= v_required_duration THEN
        v_is_completed := TRUE;
        v_points_awarded := v_scan_reward_points;

        SELECT
            user_rewards_percentage,
            cashback_percentage,
            kshipra_commission_percentage,
            business_share_percentage
        INTO
            v_user_rewards_pct,
            v_cashback_pct,
            v_kshipra_commission_pct,
            v_business_share_pct
        FROM kshipra_core.reward_distribution_config
        WHERE is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 1;

        IF NOT FOUND THEN
            v_user_rewards_pct := 50.00;
            v_cashback_pct := 25.00;
            v_kshipra_commission_pct := 25.00;
            v_business_share_pct := 0.00;
        END IF;

        IF v_location_id IS NULL OR v_business_partner_id IS NULL THEN
            v_business_share_pct := 0.00;
        ELSE
            SELECT prsc.business_share_percentage
            INTO v_override_business_share_pct
            FROM kshipra_core.partner_reward_share_config prsc
            WHERE prsc.partner_id = v_business_partner_id
              AND prsc.is_active = TRUE
              AND prsc.effective_from <= CURRENT_TIMESTAMP
            ORDER BY prsc.effective_from DESC, prsc.created_at DESC
            LIMIT 1;

            IF FOUND THEN
                v_business_share_pct := v_override_business_share_pct;
            END IF;
        END IF;

        v_max_business_share_pct := 100.00 - v_user_rewards_pct - v_cashback_pct;
        IF v_max_business_share_pct < 0 THEN
            v_max_business_share_pct := 0.00;
        END IF;
        IF v_business_share_pct > v_max_business_share_pct THEN
            v_business_share_pct := v_max_business_share_pct;
        END IF;

        v_user_rewards_cents := FLOOR(v_scan_reward_points * v_user_rewards_pct / 100);
        v_cashback_cents := FLOOR(v_scan_reward_points * v_cashback_pct / 100);
        v_business_share_cents := FLOOR(v_scan_reward_points * v_business_share_pct / 100);
        v_kshipra_commission_cents := v_scan_reward_points - v_user_rewards_cents - v_cashback_cents - v_business_share_cents;

        UPDATE kshipra_core.user_deep_link_views udlv
        SET
            completed_at = CURRENT_TIMESTAMP,
            is_completed = TRUE
        WHERE udlv.user_id::VARCHAR = p_user_id
          AND udlv.campaign_id = p_campaign_id
          AND udlv.is_completed = FALSE;

        UPDATE kshipra_core.user_profile up
        SET
            rewards_earned = COALESCE(up.rewards_earned, 0) + v_user_rewards_cents,
            cash_balance = COALESCE(up.cash_balance, 0) + (v_cashback_cents::DECIMAL / 100)
        WHERE up.user_id::VARCHAR = p_user_id;

        IF v_business_share_cents > 0 AND v_business_user_id IS NOT NULL THEN
            UPDATE kshipra_core.user_profile up
            SET rewards_earned = COALESCE(up.rewards_earned, 0) + v_business_share_cents
            WHERE up.user_id::VARCHAR = v_business_user_id;
        END IF;

        INSERT INTO kshipra_core.kshipra_earnings (
            user_id,
            campaign_id,
            qr_code_id,
            source_type,
            total_reward_points,
            commission_points,
            commission_percentage,
            earned_at,
            location_id,
            business_share_points,
            business_share_percentage
        ) VALUES (
            p_user_id,
            p_campaign_id::VARCHAR,
            v_qr_code_id,
            'scan_earn',
            v_scan_reward_points,
            v_kshipra_commission_cents,
            CASE
                WHEN v_scan_reward_points > 0 THEN ROUND((v_kshipra_commission_cents::DECIMAL / v_scan_reward_points) * 100, 2)
                ELSE v_kshipra_commission_pct
            END,
            CURRENT_TIMESTAMP,
            v_location_id,
            v_business_share_cents,
            v_business_share_pct
        );

        UPDATE kshipra_core.qr_scans qs
        SET points_awarded = v_scan_reward_points
        WHERE qs.user_id::VARCHAR = p_user_id
          AND qs.campaign_id = p_campaign_id
          AND qs.points_awarded = 0
          AND qs.scanned_at >= CURRENT_DATE;
    ELSE
        UPDATE kshipra_core.qr_scans qs
        SET points_awarded = 0
        WHERE qs.user_id::VARCHAR = p_user_id
          AND qs.campaign_id = p_campaign_id
          AND qs.scanned_at >= CURRENT_DATE;
    END IF;

    SELECT COALESCE(up.rewards_earned, 0)
    INTO v_total_points
    FROM kshipra_core.user_profile up
    WHERE up.user_id::VARCHAR = p_user_id;

    RETURN QUERY
    SELECT
        v_is_completed,
        v_points_awarded,
        v_user_rewards_cents,
        v_cashback_cents,
        v_total_points;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO kshipra_admin;

COMMENT ON TABLE kshipra_core.partner_reward_share_config IS
'Per-business override for QR host revenue share. If no active row exists for a partner, the global reward_distribution_config business share applies.';

COMMENT ON FUNCTION kshipra_core.complete_deep_link_view_session IS
'V168: Applies per-business QR host share override when a scanned QR belongs to a partner location; otherwise falls back to global business_share_percentage.';
