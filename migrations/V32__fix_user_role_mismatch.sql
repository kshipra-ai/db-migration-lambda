-- V32: Fix user role mismatch for creative.swamy@gmail.com
-- User is correctly registered as 'user' in Cognito but database has 'brand'

UPDATE kshipra_core.user_profile
SET role = 'user'
WHERE user_id = '6c6d6578-f0e1-70e0-5c7f-9a7f588af91f'
  AND email = 'creative.swamy@gmail.com'
  AND role != 'user';
