# cstatiWarehouse — backend

Go-бэкенд для iOS-клиента cstatiWarehouse. Архитектура — **Clean / Ports & Adapters**, БД — PostgreSQL, миграции — `goose`.

> Полный продуктовый и архитектурный обзор репозитория — в корневом [`README.md`](../README.md).

---

## 1. Что умеет сервер

Все фичи — на одном Go-процессе (HTTP + cron + WebSocket):

- **Аутентификация:** email/пароль (bcrypt), Telegram, Google, Apple — JWKS-валидация id_token. Refresh-токены с ротацией и revoke.
- **Организации:** роли (`owner` / `admin` / `member`), персональная организация, инвайты, передача владения, лента активности (i18n ru/en).
- **Позиции (Items):** категории, единицы измерения (`piece`, `liter`, `milliliter`, `kilogram`, `gram`), `volume_per_unit`, **варианты** (parent + variants), архивация с причинами, история списаний, soft-delete.
- **Резервирование позиций:** жизненный цикл `pending → fulfilled / cancelled / expired`, привязка к мероприятию (`event_id`), endpoint доступности.
- **Комментарии к позициям:** треды, mentions (`@username`), реакции (5 типов), soft-delete.
- **Smart Expiration Notifications:** ежедневный cron сканирует позиции на 3 уровнях (за 7д / за 1д / в день истечения), дедуп через таблицу, поддержка quiet hours и snooze.
- **APNs push** для уведомлений на iOS.
- **WebSocket** для real-time апдейтов (новые/обновлённые позиции, комментарии).
- **Аналитический дашборд** — агрегаты по организации (тренд, категории, top expiring).
- **Загрузка фото** в S3-совместимое хранилище.
- **Rate limiting:** per-IP на auth + per-user на остальное.
- **CORS, security headers, recover, structured logging.**

Подробные спеки фич — в корневом каталоге [`Docs/`](../Docs/).

---

## 2. Структура

```
backend/
├── cmd/
│   ├── server/             composition root: HTTP + cron + WebSocket hub
│   └── migrate/            CLI-обёртка над goose
├── internal/
│   ├── domain/             чистые сущности и доменные ошибки (без внешних импортов)
│   ├── usecase/            интеракторы + порты (Repository, Hasher, TokenIssuer, Clock, Verifier, Pusher)
│   ├── adapter/
│   │   ├── httpapi/        handlers, router, middleware (CORS, security, rate-limit, recover, logging)
│   │   ├── repo/           pgx-реализации портов (CQRS-разделение read/write)
│   │   ├── telegram/       JWKS-верификатор id_token
│   │   └── websocket/      Hub + Broadcaster для live-апдейтов
│   └── infra/
│       ├── config/         чтение env
│       ├── db/             pgx pool
│       ├── jwt/            HS256 issuer
│       ├── password/       bcrypt
│       ├── clock/          обёртка над time.Now()
│       ├── ratelimit/      per-IP и per-user limiter'ы
│       ├── scheduler/      cron expiration notifications
│       ├── push/           APNs HTTP/2 клиент
│       ├── i18n/           серверные локализации (активность)
│       └── s3/             загрузки в S3-совместимое хранилище
├── migrations/             SQL-миграции goose (1..25)
├── pkg/apierror/           централизованный маппинг доменных ошибок → HTTP коды
├── docs/                   архитектурные доки (CQRS, WebSocket, Observability, …)
├── docker-compose.yml      Postgres 16
├── Dockerfile              multi-stage build
├── Makefile
└── .env.example
```

### Правило зависимостей
Нижние слои не импортируют верхние:
- `domain` ничего не знает про HTTP / SQL / JSON.
- `usecase` зависит только от `domain` и собственных портов.
- `adapter/*` реализуют порты и работают с pgx / HTTP / WebSocket.
- `infra/*` — физические инструменты.
- `cmd/server/main.go` — единственное место, где всё собирается.

См. [`docs/CQRS-Repository-Split.md`](docs/CQRS-Repository-Split.md) — read и write репозитории разделены, чтобы read-side можно было направить на read-replica.

---

## 3. Требования

- Go **1.22+** (используется новый `net/http` routing с path values)
- Docker Desktop (для Postgres локально)
- `make` (опционально, ручные команды есть в Makefile)

---

## 4. Быстрый старт

```bash
cd backend
cp .env.example .env

# JWT_SECRET — обязательный, генерация:
openssl rand -hex 32

make up               # docker-compose up -d (Postgres 16)
make migrate-up       # goose миграции
make run              # HTTP-сервер на :8080 (или из .env)
```

Health-check:
```bash
curl http://localhost:8080/healthz
```

### iOS-клиент → backend
Базовый URL задаётся в схеме Xcode переменной **`BACKEND_URL`** (Edit Scheme → Run → Environment Variables) или ключом **`BackendBaseURL`** в `Info.plist`. По умолчанию — `http://localhost:8080`.

Для загрузок укажите в `.env` ключ `PUBLIC_BASE_URL` тем же адресом, что использует клиент (важно при тоннеле/LAN).

---

## 5. Конфигурация (env)

| Переменная | Назначение |
|------------|------------|
| `DATABASE_URL` | Строка подключения к Postgres |
| `LISTEN_ADDR` | Адрес HTTP-сервера (по умолчанию `:8080`) |
| `JWT_SECRET` | Секрет HS256 для access-токенов (**обязательно**) |
| `ACCESS_TOKEN_TTL`, `REFRESH_TOKEN_TTL` | Время жизни токенов |
| `PUBLIC_BASE_URL` | Базовый URL для генерируемых ссылок (uploads) |
| `TELEGRAM_CLIENT_ID` | iOS clientId; пусто → `/auth/telegram` отдаёт 503 |
| `GOOGLE_CLIENT_ID` | OAuth iOS Client ID; пусто → `/auth/google` отдаёт 503 |
| `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | Sign in with Apple |
| `APNS_*` | Конфигурация push (team id, key id, private key, bundle id, env: `dev`/`prod`) |
| `S3_*` | endpoint, region, bucket, credentials для uploads |
| `CORS_ALLOWED_ORIGINS` | Whitelist origins, через запятую |
| `EXPIRATION_CRON_HOUR` | Час запуска сканера (UTC; для пользователя сдвигается по его TZ) |

---

## 6. API

Все запросы с телом — `Content-Type: application/json`. Авторизация — `Authorization: Bearer <access_token>`.

### Auth
| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/auth/register` | email + password (+ опц. avatar URL) |
| POST | `/auth/login` | email + password |
| POST | `/auth/telegram` | `{ id_token }` — JWKS oauth.telegram.org |
| POST | `/auth/google` | `{ id_token }` — JWKS google |
| POST | `/auth/apple` | `{ id_token }` |
| POST | `/auth/refresh` | `{ refresh_token }`, ротация |
| POST | `/auth/logout` | `{ refresh_token }`, revoke |
| GET | `/auth/me` | текущий пользователь |
| PATCH | `/auth/me` | частичное обновление профиля |

Успешный ответ login/register/oauth:
```json
{
  "access_token":  "eyJhbGciOi...",
  "refresh_token": "7f3a...c9",
  "user": { "id": "uuid", "name": "...", "email": "..." }
}
```

### Items / Warehouse
| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/items` | позиции активной орг. (`?scope=mine\|all`), вложенные `variants`, `aggregated_volume_liters` |
| POST | `/items` | создать (вкл. вариант через `parent_item_id`, `variant_label`, `measure_unit`, `volume_per_unit`) |
| PUT | `/items/{id}` | полная замена |
| POST | `/items/{id}/archive` | списать с причиной (`{ reason, quantity?, eventId?, comment? }`) |
| DELETE | `/items/{id}` | hard delete (только owner/admin) |
| GET | `/categories` | строковые категории, использованные в позициях |
| GET | `/archive-events` | лента списаний (`?limit&offset`) |

`reason` ∈ `usedAtEvent | expired | disposed | lost | other`. Для `usedAtEvent` нужен `eventId`, для `other` — текст в `comment`.

### Organizations
| Метод | Путь |
|-------|------|
| GET / POST | `/organizations` |
| POST | `/organizations/join` |
| GET / PATCH / DELETE | `/organizations/{id}` |
| GET | `/organizations/{id}/members` |
| DELETE / PATCH | `/organizations/{id}/members/{userId}` |
| POST | `/organizations/{id}/transfer` |
| POST | `/organizations/{id}/leave` |
| GET / POST | `/organizations/{id}/invites` |
| DELETE | `/organizations/{id}/invites/{inviteId}` |
| GET | `/organizations/{id}/activity` |

### Events / Categories
| Метод | Путь |
|-------|------|
| GET / POST | `/events` |
| PATCH / DELETE | `/events/{id}` |
| GET / POST | `/org-categories` |
| DELETE | `/org-categories/{id}` |

### Comments
| Метод | Путь |
|-------|------|
| GET / POST | `/items/{itemID}/comments` |
| PUT / DELETE | `/comments/{commentID}` |
| POST / DELETE | `/comments/{commentID}/reactions` |

Поддерживаемые типы реакций (`type` в теле): `like`, `love`, `celebrate`, `rocket`, `eyes`. Mentions (`@username`) парсятся серверной функцией (миграция `00023`) — упомянутые получают push.

### Reservations
| Метод | Путь |
|-------|------|
| GET / POST | `/items/{itemID}/reservations` |
| GET | `/items/{itemID}/availability` |
| GET | `/organizations/{orgID}/reservations` |
| POST | `/reservations/{reservationID}/fulfill` |
| POST | `/reservations/{reservationID}/cancel` |

`POST /items/{itemID}/reservations` body:
```json
{ "quantity": 3, "event_id": "uuid", "expires_at": "2026-05-01T12:00:00Z", "note": "..." }
```

### Analytics
| Метод | Путь |
|-------|------|
| GET | `/analytics/dashboard` |

### Notifications
| Метод | Путь |
|-------|------|
| POST | `/notifications/apns-token` |
| GET / PUT | `/notifications/preferences` |
| GET | `/notifications/expiration` |
| POST | `/notifications/expiration/snooze` |

### Uploads / WebSocket
| Метод | Путь |
|-------|------|
| POST | `/uploads` (multipart) |
| GET | `/uploads/{file}` |
| GET | `/ws` (WebSocket upgrade) |
| GET | `/healthz` |

Полный список и привязка к handler'ам — в [`internal/adapter/httpapi/router.go`](internal/adapter/httpapi/router.go:32).

---

## 7. Безопасность

- **Rate limiting:**
  - `/auth/*`: per-IP, token bucket (12 запросов / 2 секунды).
  - Авторизованные эндпоинты: per-user, через [`UserLimiter`](internal/infra/ratelimit/limiter.go:1).
  - См. [`Docs/Rate-Limiting.md`](../Docs/Rate-Limiting.md).
- **CORS:** whitelist через `CORS_ALLOWED_ORIGINS`. См. [`Docs/CORS-Configuration.md`](../Docs/CORS-Configuration.md).
- **Security headers:** `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `HSTS`.
- **Recover middleware** — паника в handler'е не валит процесс.
- **bcrypt cost** настраивается через env.
- **JWT:** HS256, секрет обязателен; refresh-токены хранятся в БД с возможностью revoke.
- **File upload:** валидация MIME + лимит размера (см. [`Docs/File-Upload-Security.md`](../Docs/File-Upload-Security.md)).
- **Soft-delete** на `items` и `item_comments` — гарантирует восстановимость.

---

## 8. Telegram / Google / Apple Login

- **`POST /auth/telegram`** — нужен `TELEGRAM_CLIENT_ID` (совпадает с iOS `clientId`). Сервер валидирует подпись по JWKS `https://oauth.telegram.org/.well-known/jwks.json`, `iss`, `aud`, `exp`. Пусто → 503.
- **`POST /auth/google`** — `GOOGLE_CLIENT_ID` типа iOS (тот же, что в `GIDClientID` в iOS `Info.plist`). JWKS Google. Пусто → 503.
- **`POST /auth/apple`** — `APPLE_*` для проверки id_token и (опц.) генерации client_secret для серверной верификации.

См. [`Docs/TelegramLoginSetup.md`](../Docs/TelegramLoginSetup.md).

---

## 9. Smart Expiration Notifications (cron)

> Полная документация: [`Docs/Smart-Expiration-Notifications.md`](../Docs/Smart-Expiration-Notifications.md).

Файл: [`internal/infra/scheduler/expiration_scheduler.go`](internal/infra/scheduler/expiration_scheduler.go:1).

Алгоритм (раз в сутки):
1. Берём всех пользователей со включёнными уведомлениями и не-нулевыми позициями.
2. Для каждого позиции считаем уровень: `firstWarning` (за 7 дней до истечения), `lastWarning` (за 1 день), `expired` (день в день).
3. Уважаем quiet hours и таймзону юзера.
4. Дедуп через `expiration_notifications` (UNIQUE по `item_id` + `level` + `user_id`).
5. Шлём APNs push через [`infra/push`](internal/infra/push/).

Snooze (`POST /notifications/expiration/snooze`) — отодвигает следующее срабатывание на `1h` / `1d` / любой ISO duration.

---

## 10. WebSocket

> [`backend/docs/WebSocket-Real-Time-Updates.md`](docs/WebSocket-Real-Time-Updates.md).

`GET /ws` (с access-токеном) — клиент подключается к Hub'у, получает события:
- новые/обновлённые позиции в его организациях,
- новые комментарии под позициями,
- изменения резерваций.

Реализация: [`internal/adapter/websocket/hub.go`](internal/adapter/websocket/hub.go:1) + [`broadcaster.go`](internal/adapter/websocket/broadcaster.go:1).

---

## 11. Миграции БД

В [`migrations/`](migrations/), управляются `goose`. Текущий список (1..25):

| # | Что добавляет |
|---|---------------|
| 00001 | init: users, items, refresh_tokens |
| 00002 | profile + archive_events |
| 00003 | organizations |
| 00004 | invites + members |
| 00005 | item.location_address |
| 00006 | events |
| 00007 | categories + activity_log |
| 00008 | user.last_name |
| 00009/00010 | item.sku, price (добавлены и удалены) |
| 00011/00012 | item.minimum_quantity (добавлено и удалено) |
| 00013 | item variants + measure_unit |
| 00014 | location_address required |
| 00015 | apple/google oauth identities |
| 00016/00017 | упрощение measure_unit, восстановление pack-times |
| 00018 | device_push_tokens (APNs) |
| 00019 | composite indexes (производительность) |
| 00020 | оптимизация archive_events query |
| 00021 | soft-delete на items / comments |
| 00022 | expiration_notifications + user_notification_preferences |
| 00023 | item_comments + reactions + mention-функция |
| 00024 | item_reservations |
| 00025 | reservations event_id (вместо reasons) |

Команды:
```bash
make migrate-up
make migrate-down       # откат на 1 шаг
make migrate-status
```

---

## 12. Тестирование

```bash
make test       # go test ./...
make vet        # go vet ./...
```

- **Юнит-тесты usecase** не требуют Postgres — используют in-memory fake-репозитории ([`backend/internal/usecase/fakes_test.go`](internal/usecase/fakes_test.go)).
- **Интеграционные тесты handler'ов + БД** — [`integration_test.go`](internal/adapter/httpapi/integration_test.go), поднимают Postgres через `docker-compose`. Гайд: [`backend/docs/Integration-Testing-Guide.md`](docs/Integration-Testing-Guide.md).

---

## 13. Наблюдаемость

См. [`backend/docs/Observability.md`](docs/Observability.md):
- structured JSON-логи с `request_id`,
- метрики latency / error rate (Prometheus-совместимо),
- recover-middleware с stack-trace в логах.

---

## 14. Деплой

См. [`Docs/Deployment-Guide.md`](../Docs/Deployment-Guide.md). Для Docker:
```bash
docker build -t cstati-backend -f Dockerfile .
docker run --env-file .env -p 8080:8080 cstati-backend
```

---

*Документ актуален на момент составления. При расхождении с кодом — приоритет у исходников.*
