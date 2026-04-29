-- +goose Up
-- Заполняем пустые адреса различимыми точками в Москве (можно отредактировать в приложении).
UPDATE items
SET location_address =
    'Москва, ' ||
    (ARRAY[
        'ул. Тверская',
        'Ленинградский проспект',
        'ул. Арбат',
        'Пресненская наб.',
        'пр-т Вернадского',
        'ул. Садовая-Кудринская',
        'Широкая ул.',
        'ул. Большая Никитская'
    ])[(abs(hashtext(id::text)) % 8) + 1] ||
    ', д. ' || (10 + (abs(hashtext(coalesce(id::text, '') || 'salt')) % 40))::text
WHERE location_address IS NULL OR TRIM(location_address) = '';

ALTER TABLE items
    ADD CONSTRAINT items_location_address_nonempty
    CHECK (location_address IS NOT NULL AND length(trim(location_address)) > 0);

-- +goose Down
ALTER TABLE items DROP CONSTRAINT IF EXISTS items_location_address_nonempty;
