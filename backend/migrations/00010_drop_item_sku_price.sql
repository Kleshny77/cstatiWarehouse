-- +goose Up
-- +goose StatementBegin

-- Удаление артикула и цены — поля больше не используются.
ALTER TABLE items
    DROP COLUMN IF EXISTS sku,
    DROP COLUMN IF EXISTS price;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE items
    ADD COLUMN sku   TEXT,
    ADD COLUMN price NUMERIC(12,2);

-- +goose StatementEnd
