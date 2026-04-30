-- +goose Up
-- +goose StatementBegin

-- Add deleted_at column for soft delete functionality
ALTER TABLE items ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Add deleted_by_user_id to track who deleted the item
ALTER TABLE items ADD COLUMN deleted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Index for filtering out deleted items (most common query)
CREATE INDEX idx_items_deleted_at ON items(deleted_at) WHERE deleted_at IS NULL;

-- Index for finding deleted items (for restore/cleanup)
CREATE INDEX idx_items_deleted_at_not_null ON items(deleted_at DESC) WHERE deleted_at IS NOT NULL;

-- Index for deleted items by organization (for admin view)
CREATE INDEX idx_items_org_deleted ON items(organization_id, deleted_at DESC) WHERE deleted_at IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_items_org_deleted;
DROP INDEX IF EXISTS idx_items_deleted_at_not_null;
DROP INDEX IF EXISTS idx_items_deleted_at;
ALTER TABLE items DROP COLUMN IF EXISTS deleted_by_user_id;
ALTER TABLE items DROP COLUMN IF EXISTS deleted_at;

-- +goose StatementEnd
