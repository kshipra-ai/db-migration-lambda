-- V146__add_contribution_type_to_tree_planting_history.sql
-- Add contribution_type column to tree_planting_history to track how trees were earned
--
-- Types:
--   points_milestone  - earned by crossing 1000-point threshold (automated trigger)
--   signup_bonus      - welcome tree awarded at signup
--   donation          - user manually donated points or cash

ALTER TABLE kshipra_core.tree_planting_history
ADD COLUMN contribution_type VARCHAR(50) NOT NULL DEFAULT 'points_milestone';

COMMENT ON COLUMN kshipra_core.tree_planting_history.contribution_type IS
    'How trees were earned: points_milestone (1000pt threshold), signup_bonus (welcome tree), donation (user donated points/cash)';
