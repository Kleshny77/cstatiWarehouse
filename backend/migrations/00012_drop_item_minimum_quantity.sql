-- +goose Up
-- +goose StatementBegin

ALTER TABLE items
    DROP COLUMN IF EXISTS minimum_quantity;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS minimum_quantity INTEGER NULL;

-- +goose StatementEnd
