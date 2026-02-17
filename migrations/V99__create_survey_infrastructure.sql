-- V79: Create survey infrastructure tables for multi-provider support (BitLabs, CPX, etc.)

-- Survey providers table (BitLabs, CPX Research, Pollfish, etc.)
CREATE TABLE IF NOT EXISTS kshipra_core.survey_providers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- 'bitlabs', 'cpx', 'pollfish'
    display_name VARCHAR(100) NOT NULL, -- 'BitLabs', 'CPX Research'
    logo_url TEXT,
    is_active BOOLEAN DEFAULT true,
    
    -- Encrypted credentials stored in AWS SSM Parameter Store
    -- This column stores the SSM parameter path
    credentials_ssm_path VARCHAR(500), -- '/kshipra/surveys/bitlabs/credentials'
    
    -- Provider-specific settings
    config JSONB DEFAULT '{}', -- { minAge: 18, supportedCountries: ['US', 'CA'] }
    
    -- API endpoints
    base_url TEXT,
    webhook_path TEXT, -- '/api/webhooks/bitlabs'
    
    -- Priority order for displaying surveys (higher = show first)
    priority INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Survey catalog (synced from providers)
CREATE TABLE IF NOT EXISTS kshipra_core.surveys (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER REFERENCES kshipra_core.survey_providers(id) ON DELETE CASCADE,
    external_survey_id VARCHAR(255) NOT NULL, -- Provider's survey ID
    
    -- Normalized survey fields
    title VARCHAR(255),
    description TEXT,
    duration_minutes INTEGER NOT NULL, -- For short/long classification
    reward_cents INTEGER NOT NULL, -- Always in cents (USD)
    
    -- Metadata
    category VARCHAR(100),
    min_age INTEGER,
    max_age INTEGER,
    geo_restrictions JSONB DEFAULT '[]', -- ['US', 'CA', 'UK']
    
    -- Survey availability
    status VARCHAR(50) DEFAULT 'active', -- active/paused/expired/completed
    max_completions INTEGER, -- NULL = unlimited
    current_completions INTEGER DEFAULT 0,
    
    -- Provider-specific data (raw from API)
    provider_data JSONB DEFAULT '{}',
    
    -- Tracking
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    
    UNIQUE(provider_id, external_survey_id)
);

-- User survey responses/tracking
CREATE TABLE IF NOT EXISTS kshipra_core.user_surveys (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    survey_id INTEGER REFERENCES kshipra_core.surveys(id) ON DELETE CASCADE,
    
    -- Provider transaction tracking
    provider_transaction_id VARCHAR(255) UNIQUE, -- From webhook
    
    -- Survey state
    status VARCHAR(50) NOT NULL DEFAULT 'started', -- started/in_progress/completed/rejected/fraudulent/abandoned
    
    -- Timestamps
    started_at TIMESTAMP DEFAULT NOW(),
    submitted_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Rewards
    reward_cents INTEGER, -- Total from provider
    user_share_cents INTEGER, -- After revenue split
    bagbuddy_share_cents INTEGER, -- Platform commission
    
    -- Fraud detection
    ip_address VARCHAR(45),
    device_info JSONB DEFAULT '{}',
    completion_time_seconds INTEGER, -- Actual time taken
    
    -- Rejection handling
    rejection_reason TEXT,
    rejection_code VARCHAR(50),
    
    -- Tracking
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Indexes
    CONSTRAINT unique_user_survey UNIQUE(user_id, survey_id)
);

-- User survey preferences
CREATE TABLE IF NOT EXISTS kshipra_core.user_survey_preferences (
    user_id VARCHAR(255) PRIMARY KEY REFERENCES kshipra_core.user_profile(user_id) ON DELETE CASCADE,
    
    -- Survey length preference
    survey_length VARCHAR(20) DEFAULT 'both', -- 'short' (<=5 min), 'long' (>5 min), 'both'
    
    -- Minimum reward threshold (in cents)
    min_reward_threshold INTEGER DEFAULT 50, -- $0.50 default
    
    -- Notifications
    notify_new_surveys BOOLEAN DEFAULT true,
    
    -- Tracking
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Revenue split configuration per provider
CREATE TABLE IF NOT EXISTS kshipra_core.survey_revenue_config (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER REFERENCES kshipra_core.survey_providers(id) ON DELETE CASCADE,
    
    -- Revenue split percentages (must add up to 100)
    user_percentage DECIMAL(5,2) NOT NULL DEFAULT 70.00, -- User gets 70%
    bagbuddy_percentage DECIMAL(5,2) NOT NULL DEFAULT 30.00, -- Platform gets 30%
    
    -- Effective date range
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_until DATE, -- NULL = indefinitely
    is_active BOOLEAN DEFAULT true,
    
    -- Tracking
    created_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(255), -- Admin user who created this config
    
    -- Constraint: Only one active config per provider at a time
    CONSTRAINT check_percentages CHECK (user_percentage + bagbuddy_percentage = 100.00),
    CONSTRAINT unique_active_config UNIQUE(provider_id, is_active, effective_from)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_surveys_provider ON kshipra_core.surveys(provider_id);
CREATE INDEX IF NOT EXISTS idx_surveys_status ON kshipra_core.surveys(status);
CREATE INDEX IF NOT EXISTS idx_surveys_duration ON kshipra_core.surveys(duration_minutes);
CREATE INDEX IF NOT EXISTS idx_user_surveys_user_id ON kshipra_core.user_surveys(user_id);
CREATE INDEX IF NOT EXISTS idx_user_surveys_status ON kshipra_core.user_surveys(status);
CREATE INDEX IF NOT EXISTS idx_user_surveys_completed_at ON kshipra_core.user_surveys(completed_at);
CREATE INDEX IF NOT EXISTS idx_revenue_config_active ON kshipra_core.survey_revenue_config(provider_id, is_active);

-- Insert BitLabs as the first provider
INSERT INTO kshipra_core.survey_providers (
    name,
    display_name,
    logo_url,
    credentials_ssm_path,
    base_url,
    webhook_path,
    priority,
    config
) VALUES (
    'bitlabs',
    'BitLabs',
    'https://bitlabs.ai/logo.png',
    '/kshipra/surveys/bitlabs/credentials',
    'https://api.bitlabs.ai',
    '/api/webhooks/bitlabs',
    100,
    '{
        "minAge": 18,
        "supportedCountries": ["US", "CA", "UK", "AU"],
        "requireProfileCompletion": true
    }'::jsonb
) ON CONFLICT (name) DO NOTHING;

-- Insert default revenue split for BitLabs
INSERT INTO kshipra_core.survey_revenue_config (
    provider_id,
    user_percentage,
    bagbuddy_percentage,
    effective_from,
    created_by
) 
SELECT 
    id,
    70.00,
    30.00,
    CURRENT_DATE,
    'system'
FROM kshipra_core.survey_providers 
WHERE name = 'bitlabs'
ON CONFLICT (provider_id, is_active, effective_from) DO NOTHING;

-- Grant permissions to kshipra_admin (lambda user)
-- Note: In dev/prod, lambda functions connect as kshipra_admin
GRANT SELECT, INSERT, UPDATE ON kshipra_core.survey_providers TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE ON kshipra_core.surveys TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.user_surveys TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE ON kshipra_core.user_survey_preferences TO kshipra_admin;
GRANT SELECT ON kshipra_core.survey_revenue_config TO kshipra_admin;

-- Grant sequence usage
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.survey_providers_id_seq TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.surveys_id_seq TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.user_surveys_id_seq TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.survey_revenue_config_id_seq TO kshipra_admin;

-- Comments for documentation
COMMENT ON TABLE kshipra_core.survey_providers IS 'Supported survey providers (BitLabs, CPX Research, etc.)';
COMMENT ON TABLE kshipra_core.surveys IS 'Survey catalog synced from all active providers';
COMMENT ON TABLE kshipra_core.user_surveys IS 'Tracks user survey completions and rewards';
COMMENT ON TABLE kshipra_core.user_survey_preferences IS 'User preferences for survey length and rewards';
COMMENT ON TABLE kshipra_core.survey_revenue_config IS 'Revenue split configuration per provider';
