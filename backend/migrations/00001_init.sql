-- +goose Up
-- +goose StatementBegin
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email            TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    password_hash    TEXT,
    telegram_sub     TEXT UNIQUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (password_hash IS NOT NULL OR telegram_sub IS NOT NULL)
);

CREATE TABLE refresh_tokens (
    token_hash       TEXT PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens(user_id);

CREATE TYPE item_status AS ENUM ('in_stock', 'archived');
CREATE TYPE archive_reason AS ENUM ('usedAtEvent', 'expired', 'disposed', 'lost', 'other');

CREATE TABLE items (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name             TEXT NOT NULL,
    description      TEXT NOT NULL DEFAULT '',
    category_name    TEXT NOT NULL DEFAULT '',
    quantity         INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    status           item_status NOT NULL DEFAULT 'in_stock',
    archive_reason   archive_reason,
    archived_at      TIMESTAMPTZ,
    expiration_date  TIMESTAMPTZ,
    image_url        TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (
        (status = 'in_stock'  AND archive_reason IS NULL AND archived_at IS NULL) OR
        (status = 'archived'  AND archive_reason IS NOT NULL AND archived_at IS NOT NULL)
    )
);

CREATE INDEX items_owner_id_idx ON items(owner_id);
CREATE INDEX items_owner_status_created_idx ON items(owner_id, status, created_at DESC);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS items;
DROP TYPE IF EXISTS archive_reason;
DROP TYPE IF EXISTS item_status;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
-- +goose StatementEnd
