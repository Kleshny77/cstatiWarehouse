-- +goose Up
-- Единицы: piece, liter, milliliter, kilogram, gram. Без package/meter и без volume_per_unit.
-- Было: liter + quantity (упаковки) + volume_per_unit (л на упаковку).
-- Стало: milliliter + quantity (миллилитров всего) = round(quantity * volume_per_unit * 1000).

ALTER TABLE items DROP CONSTRAINT IF EXISTS items_measure_unit_valid;

UPDATE items SET measure_unit = 'piece' WHERE measure_unit IN ('package', 'meter');

UPDATE items
SET
    measure_unit = 'milliliter',
    quantity = GREATEST(
        1,
        ROUND((quantity::numeric * COALESCE(volume_per_unit, 1::double precision)) * 1000)::integer
    ),
    volume_per_unit = NULL
WHERE measure_unit = 'liter';

UPDATE items SET volume_per_unit = NULL;

ALTER TABLE items ADD CONSTRAINT items_measure_unit_valid CHECK (
    measure_unit IN ('piece', 'liter', 'milliliter', 'kilogram', 'gram')
);

-- +goose Down
ALTER TABLE items DROP CONSTRAINT IF EXISTS items_measure_unit_valid;
ALTER TABLE items ADD CONSTRAINT items_measure_unit_valid CHECK (
    measure_unit IN ('piece', 'package', 'meter', 'liter')
);
