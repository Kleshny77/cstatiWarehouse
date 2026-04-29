-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_sub TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub TEXT;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'users' AND c.contype = 'c'
  LOOP
    EXECUTE format('ALTER TABLE users DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE users ADD CONSTRAINT users_auth_method_check CHECK (
  password_hash IS NOT NULL
  OR telegram_sub IS NOT NULL
  OR apple_sub IS NOT NULL
  OR google_sub IS NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS users_apple_sub_key ON users (apple_sub) WHERE apple_sub IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS users_google_sub_key ON users (google_sub) WHERE google_sub IS NOT NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS users_apple_sub_key;
DROP INDEX IF EXISTS users_google_sub_key;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_auth_method_check;

ALTER TABLE users DROP COLUMN IF EXISTS apple_sub;
ALTER TABLE users DROP COLUMN IF EXISTS google_sub;

ALTER TABLE users ADD CONSTRAINT users_password_hash_telegram_sub_check CHECK (
  password_hash IS NOT NULL OR telegram_sub IS NOT NULL
);
-- +goose StatementEnd
