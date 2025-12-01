-- V97__fix_referral_reward_type.sql
-- Fix referral system configuration: change reward type from 'cash' to 'cashback'
-- to match database constraint which only allows: cashback, points, discount

UPDATE kshipra_core.system_configurations
SET config_value = jsonb_set(
    jsonb_set(config_value, '{referrer_reward,type}', '"cashback"'),
    '{referee_reward,type}', '"cashback"'
)
WHERE config_key = 'referral_system';
