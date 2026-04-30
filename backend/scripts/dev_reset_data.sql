-- Полная очистка данных приложения (dev / отладка).
-- Схему и историю миграций goose не трогает.
-- Запуск: make reset-dev-data  (из каталога backend, с поднятым Postgres и .env)

BEGIN;

TRUNCATE TABLE
    activity_log,
    categories,
    organization_invites,
    events,
    item_archive_events,
    items,
    organization_members,
    organizations,
    refresh_tokens,
    users
RESTART IDENTITY CASCADE;

COMMIT;
