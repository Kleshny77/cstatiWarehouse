-- +goose Up
-- +goose StatementBegin

-- Fix: Previous migration used wrong table name (archive_events instead of item_archive_events)
DROP INDEX IF EXISTS idx_archive_events_org_date;

-- Composite index for archive events query (organization_id + archived_at DESC)
-- This index already exists from migration 00003, but we ensure it's optimal
-- CREATE INDEX item_archive_events_organization_archived_at_idx
--     ON item_archive_events(organization_id, archived_at DESC);
-- (Already exists, no need to recreate)

-- Add index on item_id for JOIN with items table
-- This prevents sequential scan when joining item_archive_events with items
CREATE INDEX IF NOT EXISTS idx_item_archive_events_item_id
    ON item_archive_events(item_id);

-- Add index on archived_by_user_id for JOIN with users table
-- This prevents sequential scan when joining item_archive_events with users
CREATE INDEX IF NOT EXISTS idx_item_archive_events_user_id
    ON item_archive_events(archived_by_user_id);

-- Covering index for the full query (optional, for maximum performance)
-- Includes all columns needed by the query to avoid table lookups
-- Note: This is a large index, use only if archive events queries are critical
-- CREATE INDEX IF NOT EXISTS idx_item_archive_events_covering
--     ON item_archive_events(organization_id, archived_at DESC)
--     INCLUDE (id, item_id, archived_by_user_id, quantity, reason, reason_detail, event_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- DROP INDEX IF EXISTS idx_item_archive_events_covering;
DROP INDEX IF EXISTS idx_item_archive_events_user_id;
DROP INDEX IF EXISTS idx_item_archive_events_item_id;

-- Restore the incorrect index from previous migration (for rollback consistency)
CREATE INDEX IF NOT EXISTS idx_archive_events_org_date 
    ON archive_events(organization_id, archived_at DESC);

-- +goose StatementEnd
