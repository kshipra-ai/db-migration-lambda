-- V176: Add source_type to other_revenue_distribution_config for per-provider splits.
-- Allows admins to configure different user/business/Kshipra percentages per revenue source
-- (e.g. google_ad, unity_ad, theoremreach, cpx, tapjoy) independently of the global default.
--
-- Lookup priority: provider-specific active row (source_type = <key>) wins over
-- the global fallback row (source_type IS NULL).  The application queries:
--   WHERE is_active = true AND (source_type = $1 OR source_type IS NULL)
--   ORDER BY (source_type IS NOT NULL) DESC, created_at DESC LIMIT 1

ALTER TABLE kshipra_core.other_revenue_distribution_config
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(50) NULL;

-- Existing row becomes the global default (source_type stays NULL).

COMMENT ON COLUMN kshipra_core.other_revenue_distribution_config.source_type IS
'Optional provider key (e.g. ''google_ad'', ''unity_ad'', ''theoremreach'', ''cpx'', ''tapjoy'').
NULL = global default applied to all providers without a specific override row.';

-- Allow admins to insert per-provider rows without a unique violation on the PK.
-- Enforce at most one active row per source_type (NULL counts as one global row).
CREATE UNIQUE INDEX IF NOT EXISTS idx_other_rev_config_source_type_active
    ON kshipra_core.other_revenue_distribution_config (COALESCE(source_type, ''), is_active)
    WHERE is_active = TRUE;
