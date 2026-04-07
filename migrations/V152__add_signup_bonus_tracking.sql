-- Track actual signup bonus points granted to each user
-- This allows accurate revenue reporting instead of assuming all users got the bonus
ALTER TABLE kshipra_core.user_profile
    ADD COLUMN signup_bonus_points INT NOT NULL DEFAULT 0;

-- Backfill: all existing users with role='user' received the default 100-point bonus
UPDATE kshipra_core.user_profile
SET signup_bonus_points = 100
WHERE role = 'user';
