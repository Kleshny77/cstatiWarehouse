-- +goose Up
-- +goose StatementBegin

-- Гео-поле у позиций. Пока храним человеко-читаемый адрес; координаты можно добавить позже.
ALTER TABLE items ADD COLUMN location_address TEXT;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE items DROP COLUMN IF EXISTS location_address;

-- +goose StatementEnd
