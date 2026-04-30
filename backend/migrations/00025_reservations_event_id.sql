-- +goose Up
-- +goose StatementBegin

-- Резервирование переориентируется на привязку к событию (event), а не на
-- категорию заказ/поставка/производство. Удаляем избыточные поля и добавляем
-- event_id с soft FK (ON DELETE SET NULL — событие может быть удалено,
-- история броней должна сохраниться).

ALTER TABLE item_reservations
    DROP CONSTRAINT IF EXISTS item_reservations_reason_check,
    DROP CONSTRAINT IF EXISTS item_reservations_reason_detail_len;

ALTER TABLE item_reservations
    DROP COLUMN IF EXISTS reason,
    DROP COLUMN IF EXISTS reason_detail,
    DROP COLUMN IF EXISTS reference_id;

ALTER TABLE item_reservations
    ADD COLUMN event_id UUID REFERENCES events (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_item_reservations_event
    ON item_reservations (event_id)
    WHERE event_id IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_item_reservations_event;

ALTER TABLE item_reservations
    DROP COLUMN IF EXISTS event_id;

ALTER TABLE item_reservations
    ADD COLUMN reason TEXT NOT NULL DEFAULT 'other'
        CHECK (reason IN ('order', 'delivery', 'production', 'other')),
    ADD COLUMN reason_detail TEXT NOT NULL DEFAULT '',
    ADD COLUMN reference_id TEXT NOT NULL DEFAULT '';

ALTER TABLE item_reservations
    ADD CONSTRAINT item_reservations_reason_detail_len CHECK (length(reason_detail) <= 500);

-- +goose StatementEnd
