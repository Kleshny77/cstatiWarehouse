-- Удаление артикула и цены — поля больше не используются.
ALTER TABLE items
    DROP COLUMN IF EXISTS sku,
    DROP COLUMN IF EXISTS price;
