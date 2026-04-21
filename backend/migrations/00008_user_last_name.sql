-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN last_name TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE users DROP COLUMN last_name;
-- +goose StatementEnd
