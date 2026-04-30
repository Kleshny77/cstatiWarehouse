-- NOTE: paired no-op with 00012_drop_item_minimum_quantity.sql.
-- This column was rolled back before launch; the pair is preserved
-- for migration history integrity (do NOT squash on existing databases).

-- +goose Up
-- +goose StatementBegin

-- Минимальный остаток для напоминаний «осталось мало». NULL = не задан.
ALTER TABLE items
    ADD COLUMN IF NOT EXISTS minimum_quantity INTEGER NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE items
    DROP COLUMN IF EXISTS minimum_quantity;

-- +goose StatementEnd
