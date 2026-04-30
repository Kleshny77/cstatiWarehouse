-- +goose Up
-- +goose StatementBegin

ALTER TABLE items
    ADD COLUMN parent_item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    ADD COLUMN variant_label TEXT NOT NULL DEFAULT '',
    ADD COLUMN measure_unit TEXT NOT NULL DEFAULT 'piece',
    ADD COLUMN volume_per_unit DOUBLE PRECISION;

CREATE INDEX items_parent_item_id_idx ON items(parent_item_id);

ALTER TABLE items ADD CONSTRAINT items_not_self_parent CHECK (parent_item_id IS DISTINCT FROM id);

ALTER TABLE items ADD CONSTRAINT items_measure_unit_valid CHECK (
    measure_unit IN ('piece', 'package', 'meter', 'liter')
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE items DROP CONSTRAINT IF EXISTS items_measure_unit_valid;
ALTER TABLE items DROP CONSTRAINT IF EXISTS items_not_self_parent;
DROP INDEX IF EXISTS items_parent_item_id_idx;
ALTER TABLE items DROP COLUMN IF EXISTS volume_per_unit;
ALTER TABLE items DROP COLUMN IF EXISTS measure_unit;
ALTER TABLE items DROP COLUMN IF EXISTS variant_label;
ALTER TABLE items DROP COLUMN IF EXISTS parent_item_id;

-- +goose StatementEnd
