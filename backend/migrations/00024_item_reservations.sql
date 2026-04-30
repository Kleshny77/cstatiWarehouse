-- +goose Up
-- +goose StatementBegin

-- item_reservations: временные брони количества товара под заказ/доставку/производство.
-- Позволяют не проводить списание заранее, но при этом видеть «доступно = quantity - sum(active reservations)».
CREATE TABLE item_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items (id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,

    quantity INTEGER NOT NULL CHECK (quantity > 0),

    -- Категория резервирования (свободный текст в whitelist'е).
    reason TEXT NOT NULL CHECK (reason IN ('order', 'delivery', 'production', 'other')),
    reason_detail TEXT NOT NULL DEFAULT '',
    reference_id TEXT NOT NULL DEFAULT '',

    -- Lifecycle / автор
    reserved_by_user_id UUID NOT NULL REFERENCES users (id),
    reserved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,                  -- NULL = бессрочно

    -- Статус
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'fulfilled', 'cancelled', 'expired')),

    fulfilled_at TIMESTAMPTZ,
    fulfilled_by_user_id UUID REFERENCES users (id),

    cancelled_at TIMESTAMPTZ,
    cancelled_by_user_id UUID REFERENCES users (id),
    cancellation_reason TEXT NOT NULL DEFAULT '',

    notes TEXT NOT NULL DEFAULT '',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT item_reservations_reason_detail_len CHECK (length(reason_detail) <= 500),
    CONSTRAINT item_reservations_notes_len CHECK (length(notes) <= 2000),
    CONSTRAINT item_reservations_cancel_reason_len CHECK (length(cancellation_reason) <= 500)
);

-- Индексы
CREATE INDEX idx_item_reservations_item
    ON item_reservations (item_id, created_at DESC);

CREATE INDEX idx_item_reservations_organization
    ON item_reservations (organization_id, created_at DESC);

CREATE INDEX idx_item_reservations_reserved_by
    ON item_reservations (reserved_by_user_id);

-- Частичный индекс под основной запрос «активные брони этой позиции / организации».
CREATE INDEX idx_item_reservations_active
    ON item_reservations (item_id)
    WHERE status = 'active';

-- Частичный индекс под фоновый job, ищущий протухшие брони.
CREATE INDEX idx_item_reservations_expiring
    ON item_reservations (expires_at)
    WHERE status = 'active' AND expires_at IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS item_reservations;
-- +goose StatementEnd
