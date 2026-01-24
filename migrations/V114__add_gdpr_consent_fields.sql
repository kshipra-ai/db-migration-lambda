-- V113__add_gdpr_consent_fields.sql
-- Add GDPR/COPPA/CCPA compliance fields to user_profile table
-- Supports: Consent tracking, data deletion requests, audit trail

DO $$
BEGIN
    -- Add age confirmation (COPPA compliance - 13+ required)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'age_confirmed'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN age_confirmed BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added age_confirmed column';
    ELSE
        RAISE NOTICE 'age_confirmed column already exists - skipping';
    END IF;

    -- Add terms of service acceptance (GDPR/contract requirement)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'terms_accepted'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN terms_accepted BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added terms_accepted column';
    ELSE
        RAISE NOTICE 'terms_accepted column already exists - skipping';
    END IF;

    -- Add privacy policy acceptance (GDPR requirement)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'privacy_accepted'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN privacy_accepted BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added privacy_accepted column';
    ELSE
        RAISE NOTICE 'privacy_accepted column already exists - skipping';
    END IF;

    -- Add marketing consent (GDPR optional consent)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'marketing_consent'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN marketing_consent BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Added marketing_consent column';
    ELSE
        RAISE NOTICE 'marketing_consent column already exists - skipping';
    END IF;

    -- Add consent timestamp (GDPR audit requirement)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'consent_timestamp'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN consent_timestamp TIMESTAMP DEFAULT NOW();
        RAISE NOTICE 'Added consent_timestamp column';
    ELSE
        RAISE NOTICE 'consent_timestamp column already exists - skipping';
    END IF;

    -- Add consent update tracking
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'consent_updated_at'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN consent_updated_at TIMESTAMP NULL;
        RAISE NOTICE 'Added consent_updated_at column';
    ELSE
        RAISE NOTICE 'consent_updated_at column already exists - skipping';
    END IF;

    -- Add deletion request tracking (GDPR right to erasure)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'deletion_requested_at'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN deletion_requested_at TIMESTAMP NULL;
        RAISE NOTICE 'Added deletion_requested_at column';
    ELSE
        RAISE NOTICE 'deletion_requested_at column already exists - skipping';
    END IF;

    -- Add deletion reason (for compliance audit)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'deletion_reason'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN deletion_reason TEXT NULL;
        RAISE NOTICE 'Added deletion_reason column';
    ELSE
        RAISE NOTICE 'deletion_reason column already exists - skipping';
    END IF;

    -- Add scheduled deletion date (30-day grace period)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'kshipra_core' 
        AND table_name = 'user_profile' 
        AND column_name = 'deletion_scheduled_for'
    ) THEN
        ALTER TABLE kshipra_core.user_profile 
        ADD COLUMN deletion_scheduled_for TIMESTAMP NULL;
        RAISE NOTICE 'Added deletion_scheduled_for column';
    ELSE
        RAISE NOTICE 'deletion_scheduled_for column already exists - skipping';
    END IF;

    -- Update existing users to have valid consent (grandfathered in)
    -- Note: Only apply to non-deleted users created before this migration
    UPDATE kshipra_core.user_profile 
    SET 
        age_confirmed = TRUE,
        terms_accepted = TRUE,
        privacy_accepted = TRUE,
        marketing_consent = FALSE, -- Conservative default
        consent_timestamp = created_at
    WHERE 
        age_confirmed = FALSE 
        AND deleted_at IS NULL
        AND consent_timestamp IS NULL;

    RAISE NOTICE 'Updated existing users with grandfathered consent';

END $$;

-- Create index for deletion tracking (for cleanup job queries)
CREATE INDEX IF NOT EXISTS idx_user_profile_deletion_scheduled 
ON kshipra_core.user_profile(deletion_scheduled_for) 
WHERE deletion_requested_at IS NOT NULL AND deleted_at IS NULL;

-- Create index for consent timestamp (for audit queries)
CREATE INDEX IF NOT EXISTS idx_user_profile_consent_timestamp 
ON kshipra_core.user_profile(consent_timestamp) 
WHERE consent_timestamp IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN kshipra_core.user_profile.age_confirmed IS 'COPPA compliance: User confirmed they are 13+ years old';
COMMENT ON COLUMN kshipra_core.user_profile.terms_accepted IS 'GDPR compliance: User accepted Terms of Service';
COMMENT ON COLUMN kshipra_core.user_profile.privacy_accepted IS 'GDPR compliance: User accepted Privacy Policy';
COMMENT ON COLUMN kshipra_core.user_profile.marketing_consent IS 'GDPR optional consent: User opted in to marketing communications';
COMMENT ON COLUMN kshipra_core.user_profile.consent_timestamp IS 'Initial consent date/time (GDPR audit trail)';
COMMENT ON COLUMN kshipra_core.user_profile.consent_updated_at IS 'Last consent preference update (GDPR audit trail)';
COMMENT ON COLUMN kshipra_core.user_profile.deletion_requested_at IS 'GDPR right to erasure: Date/time user requested account deletion';
COMMENT ON COLUMN kshipra_core.user_profile.deletion_reason IS 'User-provided reason for account deletion (optional, for product improvement)';
COMMENT ON COLUMN kshipra_core.user_profile.deletion_scheduled_for IS 'Scheduled deletion date (30 days after request)';
