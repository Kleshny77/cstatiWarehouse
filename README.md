# cstatiWarehouse — контекст для разработки и ИИ-агентов

Документ описывает **продуктовый смысл**, **архитектуру iOS-клиента**, **взаимодействие слоёв** и **связь с бэкендом**. Цель — чтобы агент или разработчик быстро понимал, где менять логику и какие инварианты соблюдать.

---

## 1. Что это за приложение (домен)

**cstatiWarehouse** — клиент для учёта инвентаря студенческого/организационного склада:

- **Организации** — общие «склады» с участниками и ролями (`owner`, `admin`, `member`). Есть **персональная** организация (`isPersonal`), её нельзя удалить/переименовать/покинуть как обычную.
- **Позиции (Item)** — товары/материалы: название, описание, категория, количество, срок годности, фото, статус (`inStock` / `archived` с причиной), опционально «держатель» (`heldByUserID`), адрес хранения. Дополнительно: **единица учёта** (`piece` / `package` / `meter` / `liter`), для `liter` — **объём одной учётной единицы** в литрах (`volumePerUnit`); **группа с подпозициями** — корневая карточка с массивом `variants` (разные фасовки одного товара, например сок 0,7 л и 1 л); в списке API подпозиции вложены в родителя, для литровых вариантов в стаке считается **`aggregatedVolumeLiters`**.
- **Списание в архив** — частичное или полное; причины (`ArchiveReason`), для «на мероприятии» и «другое» нужен текст; можно привязать к **мероприятию** (`OrgEvent`).
- **История списаний** — отдельная лента `ArchiveEvent` (кто, когда, сколько, причина).
- **Мероприятия, категории организации, приглашения, активность** — управляются с вкладки «Организация».

Пользовательский текст и даты в UI ориентированы на **русский** (`ru_RU` там, где это задано явно, например у сроков годности позиции).

---

## 2. Технологический стек (клиент)

| Область | Выбор |
|--------|--------|
| UI | SwiftUI |
| Минимальная iOS | по настройкам Xcode-проекта |
| Состояние экранов | `@Observable` Presenter + `@Bindable` во View (см. правила в `.cursor/rules/ios-rule.mdc`) |
| Сеть | `URLSession` через единый `APIClient` |
| Анимация заставки | Lottie (`UIViewRepresentable`) |
| Telegram | пакет `TelegramLogin`, опциональная инициализация по конфигу |

В репозитории есть папка **`backend/`** (Go) — контракт REST логично сверять с реализацией сервисов в `Api*Service`.

---

## 3. Архитектура сцен (обязательный паттерн)

Каждая фича-сцена по возможности следует связке:

**Assembly → Presenter → Interactor → Router → SwiftUI View**

| Слой | Ответственность |
|------|-----------------|
| **View** | только UI, биндинги к Presenter, вызовы действий (`…Tapped`, `…Requested`) |
| **Presenter** | состояние экрана, форматирование, сборка UI-моделей, реакция на колбэки Interactor |
| **Interactor** | бизнес-операции и вызовы сервисов; `weak var presenter`; в async-колбэках `[weak self]` |
| **Router** | **только навигация** через `AppCoordinatorProtocol` (не дублировать навигацию из View) |
| **Assembly** | связывание зависимостей; по умолчанию тянет реализации из `AppServices` |

**Важно для агентов:** не протаскивать навигацию из View мимо Router; не класть бизнес-логику в `UIViewRepresentable`.

Старт экрана: **`presenter.viewDidLoad()` из `.onAppear`** (не из `init` Presenter).

---

## 4. Точка входа и оболочка приложения

Цепочка **фиксирована** правилами проекта:

1. `CstatiWarehouseApp` (`App/CstatiWarehouseApp.swift`) — тёмный фон окна до первого кадра, опционально `TelegramLogin.configure`, `RootView` в `WindowGroup`, `onOpenURL` → `TelegramLogin.handle`.
2. `RootView` (`CoreUI/Splash/SplashView.swift`) — поверх `CoordinatorView` показывается **splash ~3.5 с** с fade-out (Lottie), координатор в фоне успевает отрисоваться.
3. `CoordinatorView` — `NavigationStack` + `AppCoordinator.path`.
4. После логина — `TabBarView` с тремя вкладками.

---

## 5. Навигация и координатор

**Файлы:** `Coordinator/AppCoordinator.swift`, `Coordinator/CoordinatorView.swift`.

- `AppRoute`: `login`, `register`, `main`, `profile`.
- `AppCoordinator` держит `NavigationPath` и реализует `navigate` / `pop` / `popToRoot`.
- Корень стека — **всегда** `LoginAssembly` (даже если пользователь залогинен: при старте в `CoordinatorView.init` если `sessionStorage.isLoggedIn`, в path сразу добавляется `.main`).
- `navigationDestination(for: AppRoute.self)` открывает соответствующие Assembly.

**Профиль** в табе «Настройки» и **push на профиль** с «Мой склад» (кнопка профиля) оба ведут на `AppRoute.profile` — это **один и тот же** стек навигации: со склада нажатие добавляет `profile` в path (MyWarehouseRouter).

**Выход:** `SettingsInteractor.logout` очищает сессию и `ActiveOrganizationStorage`, затем `SettingsRouter.navigateToLogin` → `popToRoot()` — возврат к корневому Login без сохранённых маршрутов.

---

## 6. Композиция зависимостей: `AppServices`

**Файл:** `Services/AppServices.swift`.

Это **composition root** для продакшен-сборки:

- `UserDefaultsUserSessionStorage` — токены и пользователь.
- `UserDefaultsActiveOrganizationStorage` — последняя выбранная организация (UUID).
- Один общий **`APIClient(sessionStorage:)`** — все `Api*Service` используют его.

Фабрики: `authService()`, `warehouseService()`, `uploadsService()`, `organizationsService()`, `eventsService()`, `orgCategoriesService()`, `activityService()`.

**Previews и тесты** могут подставлять `Mock*` явно в Assembly (как в тестах), не обязаны идти через `AppServices`.

---

## 7. Сеть: `APIClient` и окружение

### 7.1 Базовый URL

**Файл:** `Services/Network/AppEnvironment.swift`.

- Ключ **`BackendBaseURL`** в `Info.plist` переопределяет URL без пересборки логики.
- Иначе: симулятор → `http://localhost:8080`, устройство → захардкоженный LAN IP в коде (**нужно менять под свой Mac**).

### 7.2 Поведение клиента

**Файл:** `Services/Network/APIClient.swift`.

- JSON: `snake_case` ↔ Codable, даты ISO8601 (с дробной частью и без).
- Заголовок `Authorization: Bearer <access>` для `authenticated: true`.
- **401:** очередь `refreshQueue`, синхронный вызов `/auth/refresh` с семафором, обновление токенов в `sessionStorage`, **одна** повторная попытка исходного запроса; при провале — `clear()` сессии и `.unauthorized`.
- Колбэки **`completion` всегда на main** (`completeOnMain`).
- Загрузка файлов: `upload(…)` multipart, тот же pipeline с токеном.

Ошибки сервера мапятся в `APIError` и далее в доменные ошибки сервисов (`AuthError`, `WarehouseError`, …).

---

## 8. Аутентификация и сессия

### 8.1 Потоки входа

| Поток | Где | Сервис |
|--------|-----|--------|
| Email + пароль | Login | `ApiAuthService.login` → `/auth/login` |
| Регистрация + аватар (опционально) | Register | загрузка фото → `uploadsService` → `/auth/register` |
| Telegram | Login / Register | `TelegramAuthService` → id token → `/auth/telegram` |

**Interactor** после успеха собирает `User` и вызывает `sessionStorage.save(user:accessToken:refreshToken:)`.

### 8.2 Telegram

**Файлы:** `Services/TelegramAuth/*`, `TelegramAuthConfig.swift`.

`TelegramAuthConfig.isConfigured` проверяет `clientId` и валидный **https** `redirectUri`. Если не настроено — SDK не конфигурируется в `App`, кнопка может сообщать о `notConfigured` (см. UI-компоненты логина).

Доп. документация в репозитории: `Docs/TelegramLoginSetup.md` (если присутствует).

### 8.3 Профиль

**Settings:** `PATCH /auth/me` с частичным телом; аватар сначала грузится через `UploadsService`, затем в патч уходит URL или явный сброс (`NullableString` в DTO на стороне `ApiAuthService`).

---

## 9. Доменные модели (`Entity/`)

Агенту полезно знать границу **DTO (рядом с Api*Service) ↔ Entity (домен)** — маппинг только в сервисах/интеракторах, Entity не должны знать про JSON.

Ключевые типы:

- **`User`** — id как строка (совместимость с API), имя, фамилия, email, avatar.
- **`Organization`**, **`OrganizationMember`**, **`OrganizationSummary`** (организация + роль текущего пользователя).
- **`OrgRole`** — права: `canManageMembers`, `canEditOrganization`.
- **`Item`**, **`ItemMeasureUnit`**, **`ItemStatus`**, **`ArchiveReason`**, **`ExpirationStatus`** — срок годности и бейджи для UI; у группы фильтры/сортировка учитывают варианты (`expirationStatusConsideringVariants`, `effectiveQuantityForSort`, `isEffectivelyOutOfStock`).
- **`OrgEvent`**, **`OrgCategory`**, **`OrganizationInvite`**, **`ActivityEntry`**, **`ArchiveEvent`**.

---

## 10. Сцены и бизнес-логика по разделам

### 10.1 Вкладка «Мой склад»

**Папка:** `Scenes/MyWarehouse/`.

**Назначение:** список **активных** позиций выбранной организации, поиск, фильтры, сегмент «Мои / Все» для admin/owner в неперсональной орг., переключатель организаций (список, создание, вступление по коду), создание/редактирование позиции, архивация, жёсткое удаление, история списаний.

**Interactor** (`MyWarehouseInteractor`):

1. `resolveActiveOrganization` — `GET` список организаций пользователя → выбор активной:
   - сохранённый UUID из `ActiveOrganizationStorage`, иначе
   - первая **персональная**, иначе первая в списке.
2. Загрузка позиций: `warehouseService.fetchActiveItems(organizationID, scope: .mine | .all)`.
3. `prepareArchive` — подгружает мероприятия для выбора в UI (ошибка списка событий не блокирует — пустой массив).
4. `archiveItem` / `deleteItem` — делегирование в warehouse service.

**Presenter** держит `allItems` (корни с вложенными `variants` после декодирования), локально строит **секции по категории**, фильтрует по поиску/фильтрам/«умным» фильтрам, сортирует. Поиск учитывает подписи фасовок (`variantLabel`). Отдельно хранит поиск и фильтры **по `WarehouseScope`**, чтобы при переключении «Мои / Все» состояние не смешивалось.

**Группы и списание:** у карточки с подпозициями свайп «Списать» скрыт; списание — по конкретной фасовке (из детального экрана или после выбора варианта). Контекстное меню: «Добавить фасовку» → режим `ItemEditMode.createVariant`. После сохранения варианта Presenter **вкладывает** ответ в `variants` родителя.

**Уведомления о сроке годности:** `ShelfLifeNotificationService` (`AppServices.shelfLifeNotifier`) — локальные `UNCalendarNotificationTrigger` за 30 и 7 календарных дней до дня окончания срока (в 17:00); синхронизация из `MyWarehousePresenter` по **плоскому** списку корень + все `variants` (`allStockLinesForNotifications`).

**Ошибки:** фоновые сбои первичной загрузки и списка позиций → `passiveNoticeMessage` + баннер (`PassiveNetworkBanner`); явные сбои архива/удаления → `errorMessage`.

**Router:** `navigateToProfile()`; `makeItemEditScene` собирает `ItemEditAssembly` с callback `ItemEditResult` в Presenter (`editCompleted`); режимы включают `.createVariant(parent:)`.

### 10.2 Вкладка «Организация»

**Папка:** `Scenes/Organization/`.

**Назначение:** сводка по **текущей активной** организации из `ActiveOrganizationStorage`: участники, роли, приглашения (если `canManageMembers`), переименование, выход, удаление, передача владения; отдельные шиты — мероприятия, категории, лента активности.

**Interactor** при `loadSummary`: `fetchOrganization(activeID)` → `fetchMembers` → для менеджеров ещё `loadInvites`.

**Особенности Presenter:** бизнес-правила в UI-уровне (например, нельзя выйти из персональной, владелец не может просто «выйти» без передачи владения). После leave/delete активная орг. в хранилище сбрасывается интерактором; экран очищается.

**Router** сейчас пустой протокол — навигация с этой вкладки наружу не вынесена (всё модальные шиты внутри View).

**Синхронизация со складом:** `viewDidAppear` сравнивает `activeOrganizationID` с `lastActiveOrgID` и при смене (после переключателя на складе) делает `refresh()`.

### 10.3 Вкладка «Настройки»

**Папка:** `Scenes/Settings/`.

Профиль, сохранение имени/фамилии/аватара, выход. Logout чистит и сессию, и активную организацию.

### 10.4 Редактор позиции (`ItemEdit`)

**Папка:** `Scenes/ItemEdit/`.

**Interactor** при загрузке категорий:

- параллельно: `orgCategoriesService.list` и `warehouseService.fetchCategories` (legacy-имена с позиций);
- в UI попадают категории организации + «лишние» строковые имена, которых ещё нет в орг. категориях.

**Черновик (`ItemEditDraft`):** единица учёта (`measureUnit`), строка **`volumePerUnitText`** для режима `liter`, переключатель **«Несколько фасовок одного товара»** (создание группы с количеством 0 на карточке), поле **фасовки** для `createVariant`. У карточки-группы при редактировании степпер количества скрыт (остаток на подпозициях).

Сохранение: при наличии картинки — сначала `uploadsService.uploadImage`, затем `createItem` / `updateItem` (в теле уходят `parent_item_id`, `variant_label`, `measure_unit`, `volume_per_unit` при необходимости).

### 10.5 Login / Register

Стандартные сцены с градиентным фоном и стеклянными полями (`CoreUI`). Успех → Router → `.main` или после регистрации то же.

---

## 11. Сервисы и REST (ориентир для агентов)

Реализации лежат в `Services/**/Api*Service.swift`, протоколы — `*Protocol.swift`, моки — `Mock*`.

| Протокол | Назначение | Примеры путей (не исчерпывающе) |
|-----------|------------|--------------------------------|
| `AuthServiceProtocol` | логин, регистрация, Telegram, профиль | `/auth/login`, `/auth/register`, `/auth/telegram`, `/auth/me` |
| `WarehouseServiceProtocol` | позиции (в т.ч. вложенные `variants`), архив, история, legacy-категории | `/items`, `/items/:id`, `/items/:id/archive`, `/archive-events`, `/categories` |
| `OrganizationsServiceProtocol` | орг., участники, инвайты, join по коду | см. `ApiOrganizationsService` |
| `EventsServiceProtocol` | мероприятия | см. `ApiEventsService` |
| `OrgCategoriesServiceProtocol` | категории организации | см. `ApiOrgCategoriesService` |
| `ActivityServiceProtocol` | лента активности | см. `ApiActivityService` |
| `UploadsServiceProtocol` | загрузка изображений | multipart через `APIClient.upload` |

`WarehouseScope`: **`mine`** — позиции ответственности пользователя; **`all`** — вся организация (сервер отсекает, если нет прав). В персональной организации сегмент «Мои / Все» в UI **скрыт**.

### 11.1 Бэкенд: позиции, фасовки, единицы

**Папка:** `backend/` (Go), миграции — `backend/migrations/` (в т.ч. `00013_item_variants_measure.sql`).

- В таблице `items`: `parent_item_id` (FK на родителя, `ON DELETE CASCADE`), `variant_label`, `measure_unit` (`piece` | `package` | `meter` | `liter`), `volume_per_unit` (для `liter` — литры на одну учётную единицу).
- **GET `/items`:** в JSON только **корневые** строки; у родителя с детьми — массив **`variants`** и при наличии литровых подпозиций в стаке — **`aggregated_volume_liters`**.
- **POST/PUT:** можно задать подпозицию через `parent_item_id` + `variant_label` + единицы/объём; списание **родителя** запрещено, пока есть дочерние `in_stock` с `quantity > 0` (списывать варианты по отдельности).

---

## 12. Хранилища состояния между запусками

| Хранилище | Ключевая логика |
|-----------|-----------------|
| `UserDefaultsUserSessionStorage` | пользователь (JSON), access/refresh токены |
| `UserDefaultsActiveOrganizationStorage` | UUID последней выбранной организации; чистится при logout |

`APIClient` при refresh обновляет токены через `sessionStorage.updateTokens`.

---

## 13. Общий UI и дизайн-слой

**Папка:** `CoreUI/`.

Переиспользуемые компоненты: `AnimatedGradientBackground`, `GlassTextField`, стеклянные кнопки/чипы, `CustomColors`, шиты подтверждений, `DrumDatePicker`, карточка склада `WarehouseItemCard`, баннер пассивных ошибок и т.д.

**Правило проекта:** не вводить третий визуальный стиль; авторизация — в едином «glass» стиле.

---

## 14. Тестирование

**Юнит-тесты:** `cstatiWarehouseTests/` — Interactor/Presenter (например `MyWarehousePresenterTests`, `ItemEditPresenterTests`), сервисы (`MockWarehouseServiceTests`, сессия, Telegram payload).

**UI-тесты:** `cstatiWarehouseUITests/` — минимальный каркас.

При изменении бизнес-логики — **обновлять или добавлять тесты** на уровне Presenter/Interactor/сервисов (см. правила в `.cursor/rules/ios-rule.mdc`).

---

## 15. Частые задачи агента → куда смотреть

| Задача | Место |
|--------|--------|
| Новый экран в основном flow | Assembly + Presenter + Interactor + Router + View по образцу Login/Register; регистрация маршрута в `AppRoute` + `CoordinatorView` |
| Новый API-метод | Протокол сервиса → `Api*` + DTO рядом → вызов из нужного Interactor |
| Смена URL бэкенда | `Info.plist` → `BackendBaseURL` или `AppEnvironment` |
| Поведение списка склада | `MyWarehousePresenter` (секции/фильтры/группы) + `MyWarehouseInteractor` |
| Фасовки и единицы учёта | `ItemEdit` (`ItemEditDraft`, режим `createVariant`), `ApiWarehouseService` (DTO), `Entity/Item`, миграции `backend/migrations` |
| Локальные напоминания о сроке годности | `ShelfLifeNotificationService`, `AppServices.shelfLifeNotifier`, `NotificationCenterDelegate` |
| Права в организации | `OrgRole`, проверки в `OrganizationPresenter` и на бэкенде |
| Токены / 401 | `APIClient` |
| Telegram | `TelegramAuthConfig`, `CstatiWarehouseApp`, `TelegramLoginAuthService` |

---

## 16. Зависимости Xcode / SPM

Сторонние пакеты подключаются через проект (например **Lottie**, **TelegramLogin**) — точные версии смотреть в `cstatiWarehouse.xcodeproj` / Package Dependencies.

---

Шапки Swift-файлов и нейминг модуля — см. **`.cursor/rules/ios-rule.mdc`** (в т.ч. правило: не менять уже указанную в шапке дату `Created by` при правках файла).

*Документ отражает состояние кодовой базы на момент составления; при расхождении с кодом приоритет у исходников.*
