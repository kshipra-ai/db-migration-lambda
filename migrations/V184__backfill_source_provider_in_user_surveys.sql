-- V184: Backfill source_provider for existing user_surveys rows

-- TheoremReach: rows that have a survey_id (created via ensureProviderSurvey)
UPDATE kshipra_core.user_surveys
SET source_provider = 'theoremreach'
WHERE source_provider IS NULL
  AND survey_id IS NOT NULL;

-- TapResearch: provider_transaction_id is prefixed with 'tapresearch_'
UPDATE kshipra_core.user_surveys
SET source_provider = 'tapresearch'
WHERE source_provider IS NULL
  AND provider_transaction_id LIKE 'tapresearch_%';

-- CPX: remaining rows with no survey_id and no tapresearch prefix
UPDATE kshipra_core.user_surveys
SET source_provider = 'cpx'
WHERE source_provider IS NULL;
