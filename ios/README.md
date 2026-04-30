# cstatiWarehouse — iOS-клиент

SwiftUI-приложение iOS для системы учёта склада cstatiWarehouse. Открывайте в Xcode файл [`cstatiWarehouse.xcodeproj`](cstatiWarehouse.xcodeproj/).

> Полный обзор продукта и API сервера — в корневом [`README.md`](../README.md). Серверная часть — [`../backend/`](../backend/).

---

## 1. Что умеет приложение

### Основные сценарии
- **Аутентификация:** email/пароль, **Telegram Login**, **Sign in with Apple**, **Google Sign-In**.
- **Многоорганизационная работа:** переключатель организаций, персональная организация, инвайты по коду, передача владения, роли (`owner` / `admin` / `member`).
- **Склад:**
  - список позиций активной организации, поиск, **фильтры** (категории, статус срока, держатель), **сортировки**;
  - сегмент **«Мои / Все»** для admin/owner в неперсональной организации;
  - **группы с подпозициями (variants)** с раскрытием/сворачиванием;
  - агрегация литров по подпозициям;
  - история списаний, soft-delete, восстановление.
- **Редактор позиции:** создание/редактирование, единицы измерения (`piece` / `liter` / `milliliter` / `kilogram` / `gram`), `volume_per_unit`, фото с компрессией, держатель, адрес хранения, срок годности (drum-picker).
- **Комментарии к позиции:** треды, mentions (`@username`), реакции (5 типов), edit/delete (только автор/admin), live-обновления через WebSocket.
- **Резервирование позиций:** список бронирований с фильтрами, создание под мероприятие (с inline-созданием события), fulfill / cancel с причиной.
- **Маршрут пикапа по событию:** выбор start/destination, чип-пикер мероприятия — авто-наполнение позиций по броням этого события, MapKit + ссылка на Яндекс.Карты.
- **Аналитический дашборд (Overview):** KPI, тренд остатков, распределение по категориям, top expiring — Swift Charts.
- **Smart Expiration Notifications:** многоуровневые уведомления (за 7д / 1д / в день), интерактивные actions в push-нотификации («Использовать», «Отложить 1ч/1д», «Открыть»), настройки уровней + тихих часов + таймзоны.
- **Лента активности организации.**
- **Real-time:** WebSocket-обновления (позиции, комментарии, резервации).
- **Offline-friendly:** SwiftData-кеш списков + очередь мутаций с автодоигрыванием при возврате сети.
- **Локализация:** ru/en (`Resources/Localization/`).
- **Тёмная тема** включена по дефолту, единый «glass»-стиль UI.

---

## 2. Стек

| Область | Выбор |
|---------|-------|
| UI | SwiftUI |
| Состояние сцены | `@Observable` Presenter + `@Bindable` во View |
| Concurrency | Swift 6 strict, `@MainActor` для UI |
| Сеть | `URLSession` через единый [`APIClient`](cstatiWarehouse/Services/Network/APIClient.swift:18) |
| Карты | MapKit + диплинк в Яндекс.Карты |
| Графики | Swift Charts |
| Анимации заставки | Lottie |
| Telegram | пакет `TelegramLogin` |
| Google | `GoogleSignIn` SDK |
| Apple | `AuthenticationServices` |
| Push | APNs (через сервер; локально — `UNUserNotificationCenter`) |
| Persistence | `UserDefaults` (сессия, активная орг.) + SwiftData (offline-кеш) |
| Тесты | Swift Testing (`@Suite`, `@Test`, `#expect`) + XCTest для UI |
| Минимальный iOS | задаётся в Xcode-проекте (см. Build Settings) |

---

## 3. Структура каталогов

```
ios/
├── cstatiWarehouse.xcodeproj/        проект Xcode
├── cstatiWarehouse/
│   ├── App/                          точка входа SwiftUI App + AppDelegate + Splash
│   ├── Coordinator/                  AppCoordinator, MainTabCoordinator, CoordinatorView
│   ├── Scenes/
│   │   ├── Authentication/           Login + Register
│   │   ├── MyWarehouse/              склад: список + переключатель орг. + архив
│   │   ├── ItemEdit/                 создание/редактирование позиции (+ варианты)
│   │   ├── Organization/             вкладка организации (участники/инвайты/события/категории/активность)
│   │   ├── Settings/                 профиль + ссылка на NotificationPreferences + logout
│   │   ├── Overview/                 аналитический дашборд (KPI + Charts)
│   │   ├── Comments/                 тред комментариев под позицией
│   │   ├── Reservations/             резервирование (список + создание + cancel/fulfill)
│   │   ├── RoutePlanning/            маршрут пикапа по мероприятию (MapKit + Яндекс)
│   │   ├── NotificationPreferences/  настройки уровней + тихих часов
│   │   └── TabBar/                   корневой таб-бар после логина
│   ├── Services/
│   │   ├── Network/                  APIClient, APIError, AppEnvironment
│   │   ├── Auth, OAuth, TelegramAuth, UserSession
│   │   ├── Warehouse, Reservations, Comments, Events
│   │   ├── Organizations, OrgCategories, Activity, Analytics
│   │   ├── Notifications            (preferences + smart scheduler)
│   │   ├── ShelfLife, Push          (локальные + APNs регистрация)
│   │   ├── Offline                  (OfflineMutationQueue)
│   │   ├── WebSocket                (live-обновления)
│   │   ├── LowStock, Uploads, RoutePlanning, Preview
│   │   └── AppServices.swift        composition root для прода
│   ├── Persistence/                  SwiftData offline-кеш + ключи
│   ├── Entity/                       Item, Organization, ItemReservation, ItemComment, OrgEvent, OrgRole, …
│   ├── CoreUI/                       glass-компоненты (chip, pill button, text field, sheet header, gradient bg)
│   ├── Extensions/                   Date, String, …
│   ├── Resources/Localization/       ru.lproj / en.lproj + L10n
│   └── Docs/                         iOS-специфичные стратегии (BackgroundSync, CacheInvalidation, ErrorHandling)
├── cstatiWarehouseTests/              юнит-тесты (Swift Testing)
└── cstatiWarehouseUITests/            UI-тесты (XCTest)
```

---

## 4. Архитектура сцен

**Assembly → Presenter → Interactor → Router → SwiftUI View**

| Слой | Ответственность |
|------|-----------------|
| **View** | UI, биндинги к Presenter, действия (`…Tapped`, `…Requested`) |
| **Presenter** | состояние, форматирование, UI-модели, реакция на колбэки Interactor; `@Observable` |
| **Interactor** | бизнес-операции, вызов сервисов; `weak var presenter`; `[weak self]` в async-колбэках |
| **Router** | **только** навигация через `AppCoordinatorProtocol` |
| **Assembly** | связывание зависимостей; реализации тянет из `AppServices` |

Старт сцены: `presenter.viewDidLoad()` из `.onAppear` (не из `init`).

### Точка входа
1. [`CstatiWarehouseApp`](cstatiWarehouse/App/CstatiWarehouseApp.swift:14) — тёмный фон до первого кадра, опц. `TelegramLogin.configure`, `RootView` в `WindowGroup`.
2. `RootView` — splash ~3.5 c (Lottie) поверх `CoordinatorView`.
3. `CoordinatorView` — `NavigationStack` + `AppCoordinator.path`. Корень всегда `LoginAssembly`; если `sessionStorage.isLoggedIn`, в path сразу добавляется `.main`.
4. `TabBarView` — три вкладки после логина (склад / организация / настройки).

### Композиция зависимостей
[`AppServices`](cstatiWarehouse/Services/AppServices.swift:10) — единственный composition root для прода:
- единый `APIClient(sessionStorage:)`,
- `UserDefaultsUserSessionStorage`, `UserDefaultsActiveOrganizationStorage`,
- фабрики всех сервисов: `authService()`, `warehouseService()`, `commentsService()`, `reservationsService()`, `eventsService()`, `analyticsService()`, `webSocketService`, `pushNotificationService` и т.д.

В тестах подставляются `Mock*` из [`cstatiWarehouseTests/TestDoubles/`](cstatiWarehouseTests/TestDoubles/), в `#Preview` — [`Services/Preview/PreviewServices.swift`](cstatiWarehouse/Services/Preview/PreviewServices.swift:1).

---

## 5. Сетевой клиент

[`APIClient`](cstatiWarehouse/Services/Network/APIClient.swift:18) — единая точка для HTTP:

- **JSON:** `keyDecodingStrategy = .convertFromSnakeCase` + `keyEncodingStrategy = .convertToSnakeCase`.
  - **Никогда** не используйте явные `CodingKeys` со snake_case к этим стратегиям — иначе двойная конвертация ломает декодирование.
- **Даты:** ISO8601 с дробной частью и без (два форматтера-фолбэка).
- **Auth:** заголовок `Authorization: Bearer <access>` для `authenticated: true`.
- **401 → refresh:** очередь, семафор, синхронный `/auth/refresh`, ровно одна повторная попытка; при провале — `clear()` сессии и `.unauthorized`.
- **Колбэки** всегда на main (`completeOnMain`).
- **Загрузка файлов:** `upload(...)` multipart, тот же pipeline.
- **Ретраи** на транспортные ошибки: до 3 попыток с экспоненциальной задержкой.

Ошибки сервера маппятся в `APIError` → доменные ошибки сервисов (`AuthError`, `WarehouseError`, `CommentsError`, `ReservationsError`, …).

---

## 6. Конфигурация бэкенда

### Базовый URL
[`Services/Network/AppEnvironment.swift`](cstatiWarehouse/Services/Network/AppEnvironment.swift):
- ключ **`BackendBaseURL`** в `Info.plist` имеет высший приоритет;
- иначе симулятор → `http://localhost:8080`, устройство → захардкоженный LAN IP (нужно менять под свой Mac).

### Telegram / Google / Apple
- **Telegram:** заполнить `clientId` и валидный https-`redirectUri` в `TelegramAuthConfig`. Если не настроено — кнопка показывает `notConfigured`.
- **Google:** ключ `GIDClientID` в `Info.plist`.
- **Apple:** capability «Sign in with Apple» в Xcode-проекте.

См. [`../Docs/TelegramLoginSetup.md`](../Docs/TelegramLoginSetup.md).

---

## 7. Сборка из командной строки

Из корня репозитория:

```bash
xcodebuild -project ios/cstatiWarehouse.xcodeproj \
  -scheme cstatiWarehouse \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/DerivedData \
  build
```

Папка `ios/DerivedData/` в git не коммитится (см. `.gitignore`).

---

## 8. Тестирование

```bash
xcodebuild -project ios/cstatiWarehouse.xcodeproj \
  -scheme cstatiWarehouse \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

- **Юнит** (`cstatiWarehouseTests/`) — Swift Testing:
  - сцены: `MyWarehousePresenterTests`, `LoginInteractorTelegramTests`, `RegisterInteractorValidationTests`, `OverviewPresenterTests`, `RoutePlanningInteractorTests`, `RoutePlanningPresenterTests`, …;
  - сервисы: `MockWarehouseServiceTests`, `MockAuthServiceTelegramTests`, `APIClientDateParsingTests`, `OfflineMutationQueueTests`, `PersistentUserSessionStorageTests`;
  - утилиты: `RussianQuantityStringsTests`, `PickupRouteOrderingTests`, …
- **Все Test-структуры** помечены `@MainActor` под Swift 6 strict concurrency — без этого main-actor isolated APIs (Presenter / `@Observable`) дают варнинги.
- **UI** (`cstatiWarehouseUITests/`) — XCTest: `LoginFlowUITests`, `MainTabsUITests`, accessibility ID в `UITestAccessibilityIDs.swift`.

---

## 9. Хранилища

| Хранилище | Назначение |
|-----------|------------|
| `UserDefaultsUserSessionStorage` | пользователь (JSON) + access/refresh токены |
| `UserDefaultsActiveOrganizationStorage` | UUID последней выбранной орг.; чистится при logout |
| SwiftData (`Persistence/`) | offline-кеш списка позиций по ключам [`OfflineCacheKeys`](cstatiWarehouse/Persistence/OfflineCacheKeys.swift:1) |
| `OfflineMutationQueue` | FIFO-очередь мутаций (создания/архивации/комментариев), доигрывается при возврате сети |

`APIClient` обновляет токены через `sessionStorage.updateTokens` при refresh.

---

## 10. Дизайн-слой

[`CoreUI/`](cstatiWarehouse/CoreUI/) — переиспользуемые компоненты единого «glass»-стиля:
- `AnimatedGradientBackground`, `GradientBackground`,
- `GlassTextField`, `GlassPillButton`, `GlassChip`, `GlassConfirmationSheet`,
- `FlowLayout` (для chip-flows, использовано в категориях / событиях),
- `SheetHeader`, `DrumDatePicker`,
- `WarehouseItemCard`, `RemoteImageView` + `RemoteImageCache`,
- `PassiveNetworkBanner`, `ShimmerModifier`,
- `TelegramLoginButton`, `AddressGeocodeInlinePreview`, `AddressPreviewSheet`.

**Правило проекта:** не вводить третий визуальный стиль; авторизация — в едином glass-стиле.

UI-стратегии: [`Docs/BackgroundSyncStrategy.md`](cstatiWarehouse/Docs/BackgroundSyncStrategy.md), [`CacheInvalidationStrategy.md`](cstatiWarehouse/Docs/CacheInvalidationStrategy.md), [`ErrorHandlingStrategy.md`](cstatiWarehouse/Docs/ErrorHandlingStrategy.md). Гайд по тактильному фидбэку: [`../Docs/Haptic-Feedback-Guidelines.md`](../Docs/Haptic-Feedback-Guidelines.md).

---

## 11. Зависимости (SPM)

Подключаются через Xcode (Package Dependencies). Среди них:
- **Lottie** — анимация splash;
- **TelegramLogin** — Telegram OAuth;
- **GoogleSignIn**.

Резолвенные версии — в [`cstatiWarehouse.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`](cstatiWarehouse.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved).

---

## 12. Частые задачи → куда смотреть

| Задача | Место |
|--------|-------|
| Новый экран в основном flow | `Scenes/<Name>/` (Assembly + Presenter + Interactor + Router + View) + регистрация маршрута в `AppRoute` + `CoordinatorView` |
| Новый API-метод | Протокол сервиса → `Api*Service` + DTO рядом → вызов из нужного Interactor |
| Смена URL бэкенда | `Info.plist` ключ `BackendBaseURL` или env `BACKEND_URL` в схеме Xcode |
| Поведение списка склада | `MyWarehousePresenter` (секции/фильтры/группы) + `MyWarehouseInteractor` |
| Фасовки и единицы | `ItemEdit` (`ItemEditDraft`, режим `createVariant`), `ApiWarehouseService` (DTO), `Entity/Item`, миграции в `backend/migrations` |
| Локальные expiration-уведомления | `SmartExpirationScheduler`, `ShelfLifeNotificationService`, `ExpirationNotificationActions`, `NotificationCenterDelegate` |
| Push (APNs) | `Services/Push/` + регистрация токена через `/notifications/apns-token` |
| Реакции комментариев | `Entity/ItemComment.swift` (`CommentReactionType`) + `CommentsPresenter.toggleReaction` |
| Резервации | `Scenes/Reservations/` + `Services/Reservations/ApiReservationsService.swift` |
| WebSocket-сообщение | `Services/WebSocket/WebSocketService.swift` + соответствующий Presenter |
| Права в организации | `OrgRole`, проверки в `OrganizationPresenter` (и параллельно на бэке) |
| Токены / 401 | [`APIClient`](cstatiWarehouse/Services/Network/APIClient.swift:18) |
| Telegram | `TelegramAuthConfig`, `CstatiWarehouseApp`, `TelegramLoginAuthService` |
| Lazy-загрузка картинок | `RemoteImageView` + `RemoteImageCache`; стратегия — [`../Docs/iOS-Lazy-Image-Loading.md`](../Docs/iOS-Lazy-Image-Loading.md) |

---

## 13. Стандарты кода

См. `.cursor/rules/ios-rule.mdc`:
- шапки Swift-файлов и нейминг;
- **не менять** уже указанную дату `Created by` при правках файла;
- единый glass-стиль, не вводить третий визуальный язык;
- бизнес-логика — в Presenter/Interactor, не в `UIViewRepresentable` и не во View;
- при изменении бизнес-логики — обновлять или добавлять тесты на уровне Presenter / Interactor / Service.

---

*Документ актуален на момент составления. При расхождении с кодом — приоритет у исходников.*
