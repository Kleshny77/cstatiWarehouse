-- +goose Up
-- +goose StatementBegin
CREATE TABLE device_push_tokens (
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    apns_token TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id)
);
CREATE INDEX IF NOT EXISTS idx_device_push_tokens_updated_at ON device_push_tokens (updated_at);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS device_push_tokens;
-- +goose StatementEnd
