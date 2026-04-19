-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

CREATE TABLE IF NOT EXISTS item_archive_events (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id        UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    owner_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quantity       INTEGER NOT NULL CHECK (quantity > 0),
    reason         archive_reason NOT NULL,
    reason_detail  TEXT NOT NULL DEFAULT '',
    archived_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS item_archive_events_owner_archived_at_idx
    ON item_archive_events(owner_id, archived_at DESC);

CREATE INDEX IF NOT EXISTS item_archive_events_item_id_idx
    ON item_archive_events(item_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS item_archive_events_item_id_idx;
DROP INDEX IF EXISTS item_archive_events_owner_archived_at_idx;
DROP TABLE IF EXISTS item_archive_events;
ALTER TABLE users DROP COLUMN IF EXISTS avatar_url;
-- +goose StatementEnd
