-- V140: Add signup bonus configuration to system_configurations
-- Makes signup points, welcome tree, and related settings admin-configurable

INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, is_active, updated_by)
VALUES (
    'signup_bonus',
    '{
        "enabled": true,
        "points": 100,
        "trees": 1,
        "points_for_next_tree": 1000
    }'::jsonb,
    'Signup bonus configuration: points granted and trees planted for new user signups',
    true,
    'migration'
)
ON CONFLICT (config_key) DO NOTHING;
