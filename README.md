# cstatiWarehouse

> Многофункциональная система учёта и управления складом для студенческих и небольших организационных команд.
> iOS-клиент (SwiftUI) + Go-бэкенд (Clean Architecture) + Postgres.

Документ описывает **продуктовый функционал**, **архитектуру**, **взаимодействие слоёв** и **связь клиента с бэкендом** — чтобы и человек, и ИИ-агент быстро понимал, где менять логику и какие инварианты соблюдать.

**Структура репозитория:**
- [`backend/`](backend/) — сервер на Go, REST + WebSocket
- [`ios/`](ios/) — iOS-клиент SwiftUI (`ios/cstatiWarehouse.xcodeproj`)
- [`Docs/`](Docs/) — подробные доки по фичам и инфраструктуре
- [`scripts/`](scripts/) — вспомогательные скрипты (нагрузка, чистка комментариев, проверка дашборда)

---

## 1. Продуктовый функционал

### 1.1 Организации и роли
- **Организации** — общий «склад» с участниками. Роли: `owner`, `admin`, `member` (см. [`OrgRole`](ios/cstatiWarehouse/Entity/Organization.swift:11)).
  - `canManageMembers`: owner + admin — могут приглашать, удалять, менять роли.
  - `canEditOrganization`: только owner — переименование, удаление, передача владения.
- **Персональная организация** (`isPersonal`) создаётся автоматически при регистрации, нельзя удалить/переименовать/покинуть.
- **Приглашения по коду** — owner/admin генерирует одноразовый/многоразовый инвайт-код, новый пользователь вступает через `POST /organizations/join`.
- **Передача владения** (`POST /organizations/{id}/transfer`) — единственный способ owner'у выйти из организации.
- **Лента активности** (`/organizations/{id}/activity`) — кто, что и когда сделал (i18n см. [`backend/internal/infra/i18n/activity.go`](backend/internal/infra/i18n/activity.go:1)).

### 1.2 Позиции (Item)
- **Поля:** название, описание, **категория**, **количество упаковок**, **срок годности**, **фото**, **статус** (`inStock` / `archived` с причиной), опциональный **«держатель»** (`heldByUserID`), **адрес хранения** (`location_address`).
- **Единицы измерения:** `piece`, `liter`, `milliliter`, `kilogram`, `gram`. Поле `volume_per_unit` — сколько единиц меры в одной упаковке (используется для агрегации литров).
- **Группа с подпозициями (variants):** корневая карточка + массив `variants`. Например, родитель «Сок яблочный» и подпозиции «1 л» / «0.5 л» с разным `volume_per_unit`. У литровых вариантов в стаке считается `aggregated_volume_liters`.
- **Списание родителя** запрещено, пока есть дочерние `inStock` с `quantity > 0` — списывать варианты по отдельности.
- **Архивация** — частичное или полное. Причины (`ArchiveReason`): `usedAtEvent`, `expired`, `disposed`, `lost`, `other`. Можно привязать к **мероприятию**.
- **История списаний** — отдельная лента `ArchiveEvent` (кто, когда, сколько, причина).
- **Soft-delete** (с миграции `00021`) — позиции и комментарии не удаляются физически, помечаются `deleted_at`. См. [`Docs/Soft-Delete-Implementation.md`](Docs/Soft-Delete-Implementation.md).

### 1.3 Резервирование позиций (Item Reservations)
> Полная документация: [`Docs/Item-Reservation-System.md`](Docs/Item-Reservation-System.md).

- Можно «забронировать» N упаковок позиции под событие — они становятся **недоступными для архивации**, пока бронь активна.
- **Жизненный цикл:** `pending` → `fulfilled` (использовано) | `cancelled` (отменено с причиной) | `expired` (TTL истёк).
- **Привязка к мероприятию** (`event_id`) вместо старых reasons (`order` / `delivery` / `production`) — миграция `00025_reservations_event_id`.
- **Доступность** (`GET /items/{itemID}/availability`) показывает: всего, активных бронирований, реально доступно к списанию.
- **UI:** отдельная вкладка/экран бронирований с фильтрами по статусу, инлайновое создание мероприятия из чип-пикера.

### 1.4 Комментарии к позициям (Item Comments)
> Полная документация: [`Docs/Item-Comments-System.md`](Docs/Item-Comments-System.md).

- **Тред-комментарии** под каждой позицией: создание, редактирование, удаление (только автор/admin), reply.
- **Mentions:** `@username` парсится сервером, упомянутый получает push.
- **Реакции** (`👍`, `❤️`, `🎉`, `🚀`, `👀`) — toggle одним тапом, оптимистичный UI.
- **WebSocket** обновления — комментарий долетает до всех клиентов в комнате позиции.

### 1.5 Smart Expiration Notifications
> Полная документация: [`Docs/Smart-Expiration-Notifications.md`](Docs/Smart-Expiration-Notifications.md).

- **Многоуровневые уведомления** о приближающемся сроке годности:
  - `firstWarning` (за 7 дней),
  - `lastWarning` (за 1 день),
  - `expired` (в день истечения).
- **Серверный cron** раз в сутки сканирует позиции, формирует push'и, дедуплицирует через таблицу `expiration_notifications`. См. [`backend/internal/infra/scheduler/expiration_scheduler.go`](backend/internal/infra/scheduler/expiration_scheduler.go:1).
- **Настройки пользователя** (`/notifications/preferences`): включить/выключить отдельный уровень, **тихие часы** (start/end в минутах), таймзона.
- **Snooze** (`POST /notifications/expiration/snooze`) — отложить на 1 час / 1 день.
- **iOS:** локальные уведомления-зеркала (`SmartExpirationScheduler`) + интерактивные **actions** в уведомлении: «Использовать», «Отложить 1ч / 1д», «Открыть». См. [`ExpirationNotificationActions`](ios/cstatiWarehouse/Services/Notifications/ExpirationNotificationActions.swift:11).

### 1.6 Аналитический дашборд (Overview)
> Полная документация: [`Docs/Analytics-Dashboard.md`](Docs/Analytics-Dashboard.md).

- **Главный экран** с метриками:
  - Тренд остатков по дням/неделям,
  - Распределение по категориям (pie/donut),
  - Топ-N позиций с истекающим сроком,
  - Карточки KPI: всего позиций, в процессе истечения, без держателя.
- Реализовано через `GET /analytics/dashboard` + Swift Charts на клиенте.

### 1.7 Маршрутизация и подбор по событиям (Route Planning)
- Экран **планирования маршрута пикапа**: выбираешь точку старта, точку назначения, **мероприятие** — система автоматически предлагает количество позиций, забронированных под это событие.
- Геокодирование адресов → MapKit-маршрут → ссылка в Яндекс.Карты.
- См. [`Scenes/RoutePlanning/`](ios/cstatiWarehouse/Scenes/RoutePlanning/).

### 1.8 Аутентификация
- **Email + пароль** (bcrypt на сервере),
- **Telegram Login** через `oauth.telegram.org` (id_token валидируется по JWKS), см. [`Docs/TelegramLoginSetup.md`](Docs/TelegramLoginSetup.md),
- **Sign in with Apple** + **Google Sign In** (миграция `00015_apple_google_oauth`).
- **JWT (HS256):** access (короткий) + refresh (с ротацией). Refresh-токены живут в БД с возможностью revoke.
- **iOS APIClient** при `401` сам делает `/auth/refresh` и повторяет запрос ровно раз.

### 1.9 Прочее
- **Загрузка фото** через S3-совместимое хранилище (`/uploads`), ограничения по размеру/MIME — см. [`Docs/File-Upload-Security.md`](Docs/File-Upload-Security.md), [`Docs/Image-Compression-Strategy.md`](Docs/Image-Compression-Strategy.md).
- **Push-уведомления** через APNs ([`/notifications/apns-token`](backend/internal/adapter/httpapi/router.go:106)). См. [`Docs/Push-Notifications-Enhancement.md`](Docs/Push-Notifications-Enhancement.md).
- **WebSocket** для real-time обновлений склада/комментариев ([`/ws`](backend/internal/adapter/httpapi/router.go:131)). См. [`backend/docs/WebSocket-Real-Time-Updates.md`](backend/docs/WebSocket-Real-Time-Updates.md).
- **Rate limiting:** per-IP на auth + per-user после авторизации. См. [`Docs/Rate-Limiting.md`](Docs/Rate-Limiting.md).
- **Локализация:** ru/en на iOS, серверные тексты активности через `i18n/activity.go`. См. [`Docs/Internationalization-i18n.md`](Docs/Internationalization-i18n.md).
- **Offline режим** — лёгкое кеширование списков (SwiftData) + очередь мутаций ([`OfflineMutationQueue`](ios/cstatiWarehouse/Services/Offline/OfflineMutationQueue.swift:1)) с автодоигрыванием при восстановлении сети.

---

## 2. Технологический стек

### Backend
| Область | Выбор |
|---------|-------|
| Язык | Go 1.22+ |
| HTTP | стандартная `net/http` (Go 1.22 routing) |
| БД | PostgreSQL 16, драйвер `pgx/v5` |
| Миграции | `goose` (см. [`backend/migrations/`](backend/migrations/)) |
| Аутентификация | JWT HS256, bcrypt, JWKS-валидация (Telegram/Google/Apple) |
| WebSocket | `gorilla/websocket` |
| Push | APNs (HTTP/2 JWT) |
| Файлы | S3-совместимое хранилище ([`Docs/CDN-S3-Integration.md`](Docs/CDN-S3-Integration.md)) |
| Архитектура | Clean / Ports & Adapters; CQRS-разделение репозиториев ([`backend/docs/CQRS-Repository-Split.md`](backend/docs/CQRS-Repository-Split.md)) |

### iOS
| Область | Выбор |
|---------|-------|
| UI | SwiftUI |
| Состояние | `@Observable` Presenter + `@Bindable` во View |
| Concurrency | Swift 6 strict, `@MainActor` для UI-уровня |
| Сеть | `URLSession` через единый [`APIClient`](ios/cstatiWarehouse/Services/Network/APIClient.swift:18) |
| Карты | MapKit + ссылки на Яндекс.Карты |
| Графики | Swift Charts |
| Анимации | Lottie (заставка) |
| Telegram | пакет `TelegramLogin` |
| OAuth | Apple AuthenticationServices + Google Sign-In |
| Тесты | Swift Testing (`@Suite` / `@Test` / `#expect`) + XCTest для UI |
| Persistence | `UserDefaults` (сессия, активная орг.) + SwiftData (offline-кеш) |

---

## 3. Архитектура iOS-клиента

### 3.1 Сцены — VIPER-подобный паттерн
**Assembly → Presenter → Interactor → Router → SwiftUI View**

| Слой | Ответственность |
|------|-----------------|
| **View** | только UI, биндинги к Presenter, действия (`…Tapped`, `…Requested`) |
| **Presenter** | состояние, форматирование, UI-модели, реакция на колбэки Interactor; `@Observable` |
| **Interactor** | бизнес-операции, вызов сервисов; `weak var presenter`; `[weak self]` в async |
| **Router** | **только** навигация через `AppCoordinatorProtocol` |
| **Assembly** | связывание зависимостей; реализации тянет из `AppServices` |

Старт экрана: `presenter.viewDidLoad()` из `.onAppear` (не из `init`).

### 3.2 Структура папок iOS
```
ios/cstatiWarehouse/
├── App/                    точка входа SwiftUI App, AppDelegate, splash
├── Coordinator/            AppCoordinator, MainTabCoordinator, CoordinatorView
├── Scenes/
│   ├── Authentication/     Login + Register
│   ├── MyWarehouse/        список позиций, переключатель орг., архив-история
│   ├── ItemEdit/           создание/редактирование позиции (+ варианты)
│   ├── Organization/       вкладка организации (участники, инвайты, мероприятия, категории, активность)
│   ├── Settings/           профиль, выход, ссылка на NotificationPreferences
│   ├── Overview/           аналитический дашборд
│   ├── Comments/           тред комментариев под позицией
│   ├── Reservations/       бронирования (список + создание)
│   ├── RoutePlanning/      маршрут пикапа по событию
│   ├── NotificationPreferences/   настройки уровней + тихих часов
│   └── TabBar/             корневой таб-бар после логина
├── Services/               Api*Service + протоколы + моки
│   ├── Network/            APIClient, APIError, AppEnvironment
│   ├── Auth, OAuth, TelegramAuth, UserSession
│   ├── Warehouse, Reservations, Comments, Events
│   ├── Organizations, OrgCategories, Activity, Analytics
│   ├── Notifications, ShelfLife, Push    локальные + APNs
│   ├── Offline             очередь мутаций
│   ├── WebSocket           live-обновления
│   ├── LowStock, Uploads, RoutePlanning, Preview
│   └── AppServices.swift   composition root для прода
├── Persistence/            SwiftData offline-кеш + ключи
├── Entity/                 доменные структуры (Item, Organization, ItemReservation, ItemComment, …)
├── CoreUI/                 переиспользуемые компоненты (glass-стиль)
├── Extensions/             Date, String и пр.
└── Resources/Localization/ ru.lproj / en.lproj + L10n
```

### 3.3 Композиция зависимостей
[`AppServices`](ios/cstatiWarehouse/Services/AppServices.swift:10) — единственный composition root для продакшена:
- единый `APIClient(sessionStorage:)`,
- `UserDefaultsUserSessionStorage`, `UserDefaultsActiveOrganizationStorage`,
- фабрики `authService()`, `warehouseService()`, `commentsService()`, `reservationsService()`, `eventsService()`, `analyticsService()`, `webSocketService`, `pushNotificationService` и т.д.

В тестах и `#Preview` подставляются `Mock*` из `cstatiWarehouseTests/TestDoubles/` или [`Services/Preview/PreviewServices.swift`](ios/cstatiWarehouse/Services/Preview/PreviewServices.swift:1).

### 3.4 Сетевой клиент
- JSON: `keyDecodingStrategy = .convertFromSnakeCase` + `keyEncodingStrategy = .convertToSnakeCase`. **Никогда** не пишем явные snake_case `CodingKeys` к этим стратегиям — иначе двойная конвертация ломает декодирование.
- Даты: ISO8601 с дробной частью и без (два форматтера-фолбэка).
- Заголовок `Authorization: Bearer <access>` для `authenticated: true`.
- **401 → refresh:** очередь, семафор, синхронный `/auth/refresh`, ровно одна повторная попытка; при провале — `clear()` сессии и `.unauthorized`.
- Колбэки **всегда на main** (`completeOnMain`).
- Загрузка файлов: `upload(…)` multipart, тот же pipeline.
- Ретраи на транспортные ошибки: до 3 попыток с экспоненциальной задержкой.

### 3.5 Навигация
- [`AppCoordinator`](ios/cstatiWarehouse/Coordinator/AppCoordinator.swift) держит `NavigationPath` и реализует `navigate` / `pop` / `popToRoot`.
- `AppRoute`: `login`, `register`, `main`, `profile`.
- Корень стека — всегда `LoginAssembly`; при старте если `sessionStorage.isLoggedIn`, в path сразу добавляется `.main`.
- **Logout:** очистка сессии + `ActiveOrganizationStorage` → `popToRoot()`.

---

## 4. Архитектура бэкенда

### 4.1 Слои (Clean Architecture)
```
backend/
├── cmd/
│   ├── server/             composition root: HTTP + cron + WebSocket
│   └── migrate/            CLI обёртка над goose
├── internal/
│   ├── domain/             чистые сущности и доменные ошибки (никаких импортов снаружи)
│   ├── usecase/            интеракторы + порты (Repository, Hasher, TokenIssuer, Clock, …)
│   ├── adapter/
│   │   ├── httpapi/        handlers, router, middleware (CORS, security, rate-limit, recover)
│   │   ├── repo/           pgx-реализации портов
│   │   ├── telegram/       JWKS-верификатор id_token
│   │   └── websocket/      Hub + Broadcaster для real-time
│   └── infra/
│       ├── config/         env-переменные
│       ├── db/             pgx pool
│       ├── jwt/            HS256 issuer
│       ├── password/       bcrypt
│       ├── clock/          обёртка над time.Now() для тестов
│       ├── ratelimit/      per-IP и per-user limiter'ы
│       ├── scheduler/      cron expiration notifications
│       ├── push/           APNs клиент
│       ├── i18n/           серверные локализации (активность)
│       └── s3/             загрузки
├── migrations/             SQL-миграции goose (1..25 на момент составления)
├── pkg/apierror/           централизованный маппинг доменных ошибок → HTTP коды
└── docs/                   архитектурные доки
```

### 4.2 Правило зависимостей
Нижние слои не импортируют верхние. `domain` ничего не знает про HTTP/SQL, `usecase` — только домен и собственные порты, `adapter/*` реализуют порты и работают с pgx/HTTP. Все зависимости собираются в [`cmd/server/main.go`](backend/cmd/server/main.go:1).

### 4.3 CQRS-разделение репозиториев
> [`backend/docs/CQRS-Repository-Split.md`](backend/docs/CQRS-Repository-Split.md).

Read-side и write-side репозитории — отдельные интерфейсы. Read может ходить в read-replica, write — только в primary.

---

## 5. Полный список API-эндпоинтов

> Все требуют `Authorization: Bearer <access>`, кроме раздела Auth и `/healthz`.

### Auth
| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/auth/register` | email + password (+ опц. avatar URL) |
| POST | `/auth/login` | email + password |
| POST | `/auth/telegram` | `{ id_token }` |
| POST | `/auth/google` | `{ id_token }` |
| POST | `/auth/apple` | `{ id_token }` (см. миграцию `00015`) |
| POST | `/auth/refresh` | ротация refresh-токена |
| POST | `/auth/logout` | revoke refresh |
| GET | `/auth/me` | текущий пользователь |
| PATCH | `/auth/me` | частичное обновление профиля (name, avatar) |

### Warehouse / Items
| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/items` | позиции активной орг. (`?scope=mine|all`) с вложенными `variants` |
| POST | `/items` | создать (вкл. вариант через `parent_item_id`) |
| PUT | `/items/{id}` | полная замена |
| POST | `/items/{id}/archive` | списать с причиной (`{ reason, quantity?, eventId?, comment? }`) |
| DELETE | `/items/{id}` | hard delete (только owner/admin) |
| GET | `/categories` | строковые категории, использованные в позициях |
| GET | `/archive-events` | лента списаний |

### Organizations
| Метод | Путь |
|-------|------|
| GET | `/organizations` |
| POST | `/organizations` |
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

### Analytics
| Метод | Путь |
|-------|------|
| GET | `/analytics/dashboard` |

### Comments
| Метод | Путь |
|-------|------|
| GET / POST | `/items/{itemID}/comments` |
| PUT / DELETE | `/comments/{commentID}` |
| POST / DELETE | `/comments/{commentID}/reactions` |

### Reservations
| Метод | Путь |
|-------|------|
| GET / POST | `/items/{itemID}/reservations` |
| GET | `/items/{itemID}/availability` |
| GET | `/organizations/{orgID}/reservations` |
| POST | `/reservations/{reservationID}/fulfill` |
| POST | `/reservations/{reservationID}/cancel` |

### Notifications
| Метод | Путь |
|-------|------|
| POST | `/notifications/apns-token` |
| GET / PUT | `/notifications/preferences` |
| GET | `/notifications/expiration` |
| POST | `/notifications/expiration/snooze` |

### Uploads / Misc
| Метод | Путь |
|-------|------|
| POST | `/uploads` (multipart) |
| GET | `/uploads/{file}` |
| GET | `/ws` (WebSocket upgrade) |
| GET | `/healthz` |

---

## 6. Безопасность и ограничения

- **Rate limiting:** per-IP на `/auth/*` (token bucket 12 запросов / 2 секунды), per-user на остальное. См. [`Docs/Rate-Limiting.md`](Docs/Rate-Limiting.md), [`backend/internal/infra/ratelimit/limiter.go`](backend/internal/infra/ratelimit/limiter.go:1).
- **CORS:** whitelist через env (`CORS_ALLOWED_ORIGINS`). См. [`Docs/CORS-Configuration.md`](Docs/CORS-Configuration.md).
- **Security headers:** `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security` (см. [`middleware_security.go`](backend/internal/adapter/httpapi/middleware_security.go:1)).
- **Recover middleware:** ловит панику в handler'ах, отдаёт 500 без падения процесса.
- **Логирование:** structured (JSON), с request-id; не логируем тела запросов с паролями.
- **bcrypt cost** настраивается через env.
- **JWT секрет** (`JWT_SECRET`) — обязательный, рекомендация: `openssl rand -hex 32`.
- **File upload:** валидация MIME + лимит размера (см. [`Docs/File-Upload-Security.md`](Docs/File-Upload-Security.md)).

---

## 7. База данных

> Миграции в [`backend/migrations/`](backend/migrations/) (1..25 на момент составления).

Ключевые таблицы:
- `users`, `user_oauth_identities`, `refresh_tokens`, `device_push_tokens`
- `organizations`, `organization_members`, `organization_invites`
- `items` (с `parent_item_id`, `measure_unit`, `volume_per_unit`, soft-delete)
- `archive_events`, `org_events`, `org_categories`, `activity_log`
- `expiration_notifications`, `user_notification_preferences`
- `item_comments`, `item_comment_reactions`
- `item_reservations` (с `event_id` после `00025`)

Композитные индексы и оптимизации см. [`Docs/Database-Query-Optimization.md`](Docs/Database-Query-Optimization.md), миграции `00019`, `00020`.

---

## 8. Быстрый старт

### Backend
```bash
cd backend
cp .env.example .env
# JWT_SECRET — обязательный:
# openssl rand -hex 32

make up               # docker-compose: Postgres
make migrate-up       # накатываем миграции
make run              # HTTP-сервер (порт из .env, по умолчанию :8080)

curl http://localhost:8080/healthz
```

### iOS
1. Открыть [`ios/cstatiWarehouse.xcodeproj`](ios/cstatiWarehouse.xcodeproj/) в Xcode 16+.
2. Указать backend URL:
   - **Edit Scheme → Run → Arguments → Environment Variables:** `BACKEND_URL=http://localhost:8080`, либо
   - ключ **`BackendBaseURL`** в `Info.plist`.
3. (Опционально) для Telegram/Google заполнить соответствующие конфиги — см. [`Docs/TelegramLoginSetup.md`](Docs/TelegramLoginSetup.md).
4. Run на симуляторе или устройстве (для устройства — backend должен быть в той же LAN, в `.env` укажите `PUBLIC_BASE_URL` тем же адресом).

### Скрипты
```bash
scripts/loadtest.sh                 # k6/wrk нагрузочный тест базовых эндпоинтов
scripts/check_analytics_dashboard.sh
```

---

## 9. Тестирование

### Backend
```bash
cd backend
make test       # go test ./... (юнит — без Postgres, использует in-memory fake-репозитории)
make vet
```
Интеграционные тесты handler'ов + БД — см. [`backend/internal/adapter/httpapi/integration_test.go`](backend/internal/adapter/httpapi/integration_test.go) и [`backend/docs/Integration-Testing-Guide.md`](backend/docs/Integration-Testing-Guide.md).

### iOS
```bash
cd ios
xcodebuild -project cstatiWarehouse.xcodeproj \
  -scheme cstatiWarehouse \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```
- **Юнит:** `cstatiWarehouseTests/` — Swift Testing, покрывают Presenter/Interactor/Service. Все Test-структуры помечены `@MainActor` под Swift 6 strict concurrency.
- **UI:** `cstatiWarehouseUITests/` — XCTest, базовые сценарии логина и табов.

---

## 10. Документация по фичам

В [`Docs/`](Docs/) лежат подробные доки:

| Тема | Файл |
|------|------|
| Smart Expiration Notifications | [`Smart-Expiration-Notifications.md`](Docs/Smart-Expiration-Notifications.md) |
| Item Comments System | [`Item-Comments-System.md`](Docs/Item-Comments-System.md) |
| Item Reservation System | [`Item-Reservation-System.md`](Docs/Item-Reservation-System.md) |
| Analytics Dashboard | [`Analytics-Dashboard.md`](Docs/Analytics-Dashboard.md) |
| Push Notifications | [`Push-Notifications-Enhancement.md`](Docs/Push-Notifications-Enhancement.md) |
| Soft Delete | [`Soft-Delete-Implementation.md`](Docs/Soft-Delete-Implementation.md) |
| Rate Limiting | [`Rate-Limiting.md`](Docs/Rate-Limiting.md) |
| CORS Configuration | [`CORS-Configuration.md`](Docs/CORS-Configuration.md) |
| Internationalization | [`Internationalization-i18n.md`](Docs/Internationalization-i18n.md) |
| File Upload Security | [`File-Upload-Security.md`](Docs/File-Upload-Security.md) |
| Image Compression | [`Image-Compression-Strategy.md`](Docs/Image-Compression-Strategy.md) |
| iOS Lazy Image Loading | [`iOS-Lazy-Image-Loading.md`](Docs/iOS-Lazy-Image-Loading.md) |
| CDN / S3 | [`CDN-S3-Integration.md`](Docs/CDN-S3-Integration.md) |
| DB Query Optimization | [`Database-Query-Optimization.md`](Docs/Database-Query-Optimization.md) |
| OpenAPI / Swagger | [`OpenAPI-Swagger-Documentation.md`](Docs/OpenAPI-Swagger-Documentation.md) |
| Telegram Login Setup | [`TelegramLoginSetup.md`](Docs/TelegramLoginSetup.md) |
| Haptic Feedback Guidelines | [`Haptic-Feedback-Guidelines.md`](Docs/Haptic-Feedback-Guidelines.md) |
| Deployment | [`Deployment-Guide.md`](Docs/Deployment-Guide.md) |
| ADR | [`Docs/ADR/`](Docs/ADR/) |

Backend-специфичная документация: [`backend/docs/`](backend/docs/) — Context-UserID-Migration, CQRS-Repository-Split, Feature-Implementation-Roadmap, Integration-Testing-Guide, Observability, WebSocket-Real-Time-Updates.

iOS-специфичная: [`ios/cstatiWarehouse/Docs/`](ios/cstatiWarehouse/Docs/) — BackgroundSyncStrategy, CacheInvalidationStrategy, ErrorHandlingStrategy.

---

## 11. Частые задачи → куда смотреть

| Задача | Файлы / места |
|--------|---------------|
| Новый экран iOS | `Scenes/<Name>/Assembly+Presenter+Interactor+Router+View.swift` + регистрация маршрута в `AppRoute` + `CoordinatorView` |
| Новый API-метод | iOS: протокол сервиса → `Api*Service` + DTO. Backend: handler → usecase → repo + порт |
| Смена URL бэкенда | `Info.plist` ключ `BackendBaseURL` или env `BACKEND_URL` в схеме Xcode |
| Новый тип уведомления | `ExpirationLevel` + `SmartExpirationScheduler` + бэкенд-cron |
| Новая реакция в комментариях | `CommentReactionType` (iOS + backend `domain.CommentReactionType`) |
| Новый статус резервации | `ReservationStatus` + миграция при добавлении DB-столбца |
| Права в организации | `OrgRole` (iOS) + `domain.OrgRole` (backend) + проверки в usecase |
| 401 / refresh | [`APIClient`](ios/cstatiWarehouse/Services/Network/APIClient.swift:18) |
| WebSocket-сообщение | `backend/internal/adapter/websocket/broadcaster.go` + iOS `WebSocketService` |
| Push на устройство | APNs: `backend/internal/infra/push/` + iOS `PushNotificationService` |

---

## 12. Стандарты кода

- **Swift:** `.cursor/rules/ios-rule.mdc` — шапки файлов, нейминг, не менять `Created by` дату, единый glass-стиль UI, не вводить третий визуальный язык.
- **Go:** `gofmt`, `go vet`, error wrapping (`fmt.Errorf("...: %w", err)`), `pgx.ErrNoRows` маппится в доменные ошибки в repo-слое.
- **Коммиты / VCS:** см. [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

*Документ отражает состояние кодовой базы на момент составления. При расхождении с кодом приоритет у исходников.*
