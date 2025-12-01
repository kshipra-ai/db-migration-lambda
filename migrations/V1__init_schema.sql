-- Schema and first table
CREATE SCHEMA IF NOT EXISTS app;
SET search_path = app, public;

CREATE TABLE IF NOT EXISTS app.app_user (
  user_id    TEXT PRIMARY KEY,                -- Cognito sub
  email      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Optional: grant your app user (run once after the app user exists)
-- GRANT USAGE ON SCHEMA app TO kshipra_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON app.app_user TO kshipra_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA app
--   GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kshipra_app;
