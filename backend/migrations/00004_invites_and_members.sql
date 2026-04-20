-- +goose Up
-- +goose StatementBegin

-- Приглашения по коду: многоразовые, с опциональным сроком и лимитом использований.
CREATE TABLE organization_invites (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    code               TEXT NOT NULL UNIQUE,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at         TIMESTAMPTZ,
    max_uses           INTEGER,
    used_count         INTEGER NOT NULL DEFAULT 0,
    revoked_at         TIMESTAMPTZ
);

CREATE INDEX organization_invites_org_idx ON organization_invites(organization_id);
CREATE INDEX organization_invites_code_idx ON organization_invites(code);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS organization_invites_code_idx;
DROP INDEX IF EXISTS organization_invites_org_idx;
DROP TABLE IF EXISTS organization_invites;

-- +goose StatementEnd
