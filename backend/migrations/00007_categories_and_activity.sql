-- +goose Up
-- +goose StatementBegin

-- Справочник категорий организации. Имя уникально в рамках организации.
CREATE TABLE categories (
    id               UUID PRIMARY KEY,
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name             TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_categories_org_name_ci ON categories (organization_id, lower(name));

-- Журнал действий организации. Append-only, читается с сортировкой DESC по created_at.
CREATE TABLE activity_log (
    id               UUID PRIMARY KEY,
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    actor_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kind             TEXT NOT NULL,
    target_type      TEXT NOT NULL DEFAULT '',
    target_id        UUID,
    summary          TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_activity_log_org_created_at ON activity_log (organization_id, created_at DESC);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_activity_log_org_created_at;
DROP TABLE IF EXISTS activity_log;

DROP INDEX IF EXISTS idx_categories_org_name_ci;
DROP TABLE IF EXISTS categories;

-- +goose StatementEnd
