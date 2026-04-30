-- +goose Up
-- +goose StatementBegin
-- Composite index for frequent warehouse queries filtering by organization, status, and holder
CREATE INDEX IF NOT EXISTS idx_items_org_status_holder 
ON items(organization_id, status, held_by_user_id);

-- Index for expiration date queries (notifications, warnings)
CREATE INDEX IF NOT EXISTS idx_items_expiration_date 
ON items(expiration_date) 
WHERE expiration_date IS NOT NULL AND status = 'in_stock';

-- Index for archive events by organization and date
CREATE INDEX IF NOT EXISTS idx_item_archive_events_org_date
ON item_archive_events(organization_id, archived_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_item_archive_events_org_date;
DROP INDEX IF EXISTS idx_items_expiration_date;
DROP INDEX IF EXISTS idx_items_org_status_holder;
-- +goose StatementEnd
