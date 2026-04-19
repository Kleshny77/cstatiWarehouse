# cstatiWarehouse backend

Go-бэкенд для iOS-клиента cstatiWarehouse. Сейчас поднимается локально, архитектурно — Clean / Ports & Adapters.

## Структура

```
backend/
├── cmd/
│   ├── server/          composition root: HTTP-сервер
│   └── migrate/         CLI для миграций (goose)
├── internal/
│   ├── domain/          сущности и доменные ошибки (ничего не импортит извне)
│   ├── usecase/         интеракторы + порты (Repository, Hasher, TokenIssuer, Clock, TelegramVerifier)
│   ├── adapter/
│   │   ├── httpapi/     HTTP-handlers, router, middleware
│   │   ├── repo/        Repository-реализации поверх Postgres (pgx)
│   │   └── telegram/    верификатор id_token через JWKS oauth.telegram.org
│   └── infra/
│       ├── config/      чтение env-переменных
│       ├── db/          подключение к Postgres
│       ├── jwt/         выпуск/валидация наших access-токенов (HS256)
│       ├── password/    bcrypt
│       └── clock/       time.Now-обёртка для тестов
├── migrations/          SQL миграции (goose)
├── docker-compose.yml   Postgres 16
├── Makefile             команды для разработки
└── .env.example
```

## Слои и зависимости

- `domain` — чистые структуры и ошибки. Не зависит ни от чего.
- `usecase` — бизнес-логика. Зависит только от `domain` и от собственных портов.
- `adapter/*` — реализуют порты usecase и отвечают за ввод/вывод (HTTP, БД, Telegram).
- `infra/*` — «физические» инструменты: pgx-пул, bcrypt-хэшер, HS256-issuer, слой конфига.
- `cmd/server/main.go` — единственная точка, где всё собирается вместе.

Правило: нижние слои не импортируют верхние. `domain` не знает про HTTP, `usecase` не знает про pgx и `net/http`.

## Требования

- Go 1.22+
- Docker Desktop (для Postgres)

## Быстрый старт

```bash
cd backend
cp .env.example .env
# Сгенерировать сильный JWT_SECRET:
#   openssl rand -hex 32

make up               # поднимаем Postgres
make migrate-up       # накатываем миграции
make run              # стартуем HTTP-сервер на :8080
```

Проверить, что живой:

```bash
curl http://localhost:8080/healthz
```

## API

Все запросы с телом — `Content-Type: application/json`. Авторизация — `Authorization: Bearer <access_token>`.

### Auth

| Метод | Путь               | Описание                                  |
| ----- | ------------------ | ----------------------------------------- |
| POST  | `/auth/register`   | email + password                          |
| POST  | `/auth/login`      | email + password                          |
| POST  | `/auth/telegram`   | `{ "id_token": "..." }`                   |
| POST  | `/auth/refresh`    | `{ "refresh_token": "..." }`, ротация     |
| POST  | `/auth/logout`     | `{ "refresh_token": "..." }`, revoke      |
| GET   | `/auth/me`         | текущий пользователь по access-токену     |

Успешный ответ login/register/telegram:

```json
{
  "access_token":  "eyJhbGciOi...",
  "refresh_token": "7f3a...c9",
  "user": { "id": "uuid", "name": "...", "email": "..." }
}
```

### Warehouse

Всё требует access-токен. Пользователь видит только свои позиции.

| Метод  | Путь                    | Описание                                       |
| ------ | ----------------------- | ---------------------------------------------- |
| GET    | `/items`                | Список всех позиций текущего пользователя      |
| POST   | `/items`                | Создать                                         |
| PUT    | `/items/{id}`           | Обновить (полная замена полей)                  |
| POST   | `/items/{id}/archive`   | Списать (`{ "reason": "usedAtEvent\|expired\|disposed\|lost\|other" }`) |
| DELETE | `/items/{id}`           | Удалить навсегда                                |
| GET    | `/categories`           | Уникальные категории пользователя              |

## Telegram Login

Для `POST /auth/telegram` нужно заполнить `TELEGRAM_CLIENT_ID` (значение совпадает с `clientId` в iOS). Сервер скачает JWKS с `https://oauth.telegram.org/.well-known/jwks.json` и провалидирует:

- подпись,
- `iss == https://oauth.telegram.org`,
- `aud == TELEGRAM_CLIENT_ID`,
- `exp > now`.

Пока переменная пустая — эндпоинт возвращает `503 telegram login not configured`.

## Тесты

```bash
make test      # go test ./...
make vet       # go vet ./...
```

Unit-тесты usecase не требуют Postgres — используют in-memory фейковые репозитории.
