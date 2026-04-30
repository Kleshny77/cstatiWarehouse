-- +goose Up
-- +goose StatementBegin

-- expiration_notifications: дедупликация отправленных уведомлений об истечении.
-- Уникальный (item_id, level) гарантирует, что для каждой позиции каждый уровень
-- (early_warning / action_required / critical / expired) отправляется ровно один раз.
CREATE TABLE expiration_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items (id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    level TEXT NOT NULL CHECK (level IN ('early_warning', 'action_required', 'critical', 'expired')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivery_status TEXT NOT NULL DEFAULT 'sent' CHECK (delivery_status IN ('sent', 'failed', 'snoozed')),
    snooze_until TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_expiration_notifications_item_level_user
    ON expiration_notifications (item_id, level, user_id);

CREATE INDEX idx_expiration_notifications_org
    ON expiration_notifications (organization_id, sent_at DESC);

CREATE INDEX idx_expiration_notifications_user_recent
    ON expiration_notifications (user_id, sent_at DESC);

-- user_notification_preferences: персонализация (включение уровней, тихие часы, таймзона).
CREATE TABLE user_notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    early_warning_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    action_required_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    critical_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    expired_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours_start_minute INT NOT NULL DEFAULT 1320 CHECK (quiet_hours_start_minute BETWEEN 0 AND 1439),
    quiet_hours_end_minute INT NOT NULL DEFAULT 480 CHECK (quiet_hours_end_minute BETWEEN 0 AND 1439),
    timezone TEXT NOT NULL DEFAULT 'Europe/Moscow',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS user_notification_preferences;
DROP TABLE IF EXISTS expiration_notifications;
-- +goose StatementEnd
