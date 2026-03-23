-- V142: Fix NULL and FALSE values for points_awarded in campaign_chat_sessions
-- Ensures already_earned_chat_points backend query works correctly
-- Sets points_awarded=true for sessions where valid_question_count >= 10

UPDATE kshipra_core.campaign_chat_sessions
SET points_awarded = CASE 
    WHEN valid_question_count >= 10 THEN true
    ELSE false
END
WHERE points_awarded IS NULL
   OR (points_awarded = false AND valid_question_count >= 10);
