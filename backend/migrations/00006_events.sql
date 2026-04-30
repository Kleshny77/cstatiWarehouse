-- +goose Up
-- +goose StatementBegin

-- Мероприятия организации. Обычно это конференции, выезды, активности,
-- на которые списывается часть стоков. К item_archive_events можно привязать event_id,
-- чтобы получить историю "что именно ушло на это мероприятие".
CREATE TABLE events (
    id               UUID PRIMARY KEY,
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name             TEXT NOT NULL,
    description      TEXT NOT NULL DEFAULT '',
    starts_at        TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_org_starts_at ON events (organization_id, starts_at DESC NULLS LAST, created_at DESC);

ALTER TABLE item_archive_events ADD COLUMN event_id UUID REFERENCES events(id) ON DELETE SET NULL;
CREATE INDEX idx_item_archive_events_event ON item_archive_events (event_id) WHERE event_id IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_item_archive_events_event;
ALTER TABLE item_archive_events DROP COLUMN IF EXISTS event_id;

DROP INDEX IF EXISTS idx_events_org_starts_at;
DROP TABLE IF EXISTS events;

-- +goose StatementEnd
