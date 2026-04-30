-- NOTE: paired no-op with 00010_drop_item_sku_price.sql.
-- These columns were never released; the pair is preserved for migration
-- history integrity (do NOT squash on existing databases).

-- +goose Up
-- +goose StatementBegin
ALTER TABLE items
    ADD COLUMN sku   TEXT,
    ADD COLUMN price NUMERIC(12,2);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE items
    DROP COLUMN IF EXISTS sku,
    DROP COLUMN IF EXISTS price;
-- +goose StatementEnd
