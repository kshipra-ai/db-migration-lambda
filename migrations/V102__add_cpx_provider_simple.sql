-- V101: Add CPX Research as a survey provider
-- Simple migration to add CPX provider to the database

INSERT INTO kshipra_core.survey_providers (
    name,
    display_name,
    is_active,
    created_at,
    updated_at
) VALUES (
    'cpx',
    'CPX Research',
    true,
    NOW(),
    NOW()
) ON CONFLICT (name) DO NOTHING;