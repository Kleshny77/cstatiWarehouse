-- +goose Up
-- +goose StatementBegin

-- ПРЕДУПРЕЖДЕНИЕ: миграция делает колонки items.organization_id и held_by_user_id
-- обязательными (NOT NULL) без бэкфилла. Перед накатом на существующую базу
-- с данными выполните `make migrate-down` или снесите volume (dev-only).

CREATE TYPE org_role AS ENUM ('owner', 'admin', 'member');

CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    owner_id    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    is_personal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX organizations_owner_idx ON organizations(owner_id);

CREATE TABLE organization_members (
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            org_role NOT NULL,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, user_id)
);

CREATE INDEX organization_members_user_idx ON organization_members(user_id);

-- items: привязка к организации и держателю.
-- owner_id (личный владелец) больше не нужен — все айтемы в контексте организации.
ALTER TABLE items DROP COLUMN owner_id;
ALTER TABLE items ADD COLUMN organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE items ADD COLUMN held_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT;

DROP INDEX IF EXISTS items_owner_id_idx;
DROP INDEX IF EXISTS items_owner_status_created_idx;

CREATE INDEX items_organization_idx ON items(organization_id);
CREATE INDEX items_organization_status_created_idx ON items(organization_id, status, created_at DESC);
CREATE INDEX items_held_by_idx ON items(held_by_user_id);

-- Архивные события: теперь отражают, КТО списал и В КАКОЙ организации.
-- Старое owner_id (владелец айтема) семантически эквивалентно archived_by_user_id,
-- так как до этапа "организации" списывать мог только владелец.
ALTER TABLE item_archive_events DROP COLUMN owner_id;
ALTER TABLE item_archive_events ADD COLUMN organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE item_archive_events ADD COLUMN archived_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT;

DROP INDEX IF EXISTS item_archive_events_owner_archived_at_idx;

CREATE INDEX item_archive_events_organization_archived_at_idx
    ON item_archive_events(organization_id, archived_at DESC);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS item_archive_events_organization_archived_at_idx;
ALTER TABLE item_archive_events DROP COLUMN IF EXISTS archived_by_user_id;
ALTER TABLE item_archive_events DROP COLUMN IF EXISTS organization_id;
ALTER TABLE item_archive_events ADD COLUMN owner_id UUID;
CREATE INDEX IF NOT EXISTS item_archive_events_owner_archived_at_idx
    ON item_archive_events(owner_id, archived_at DESC);

DROP INDEX IF EXISTS items_held_by_idx;
DROP INDEX IF EXISTS items_organization_status_created_idx;
DROP INDEX IF EXISTS items_organization_idx;
ALTER TABLE items DROP COLUMN IF EXISTS held_by_user_id;
ALTER TABLE items DROP COLUMN IF EXISTS organization_id;
ALTER TABLE items ADD COLUMN owner_id UUID;
CREATE INDEX IF NOT EXISTS items_owner_id_idx ON items(owner_id);
CREATE INDEX IF NOT EXISTS items_owner_status_created_idx ON items(owner_id, status, created_at DESC);

DROP TABLE IF EXISTS organization_members;
DROP TABLE IF EXISTS organizations;
DROP TYPE IF EXISTS org_role;

-- +goose StatementEnd
