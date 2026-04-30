# cstatiWarehouse — основной справочник проекта

> **Цель документа.** Дать ИИ-модели или новому разработчику исчерпывающий контекст для написания **любой документации** к проекту: от пользовательских мануалов до архитектурных ADR. Здесь — **продуктовый смысл**, **поведение каждого экрана**, **полный API**, **схема БД**, **архитектура iOS и backend**, **инварианты**, **безопасность**, **тестирование**, **гайды по задачам**.

> При расхождении с кодом приоритет у исходников. Этот документ обновляется при изменении функциональности.

**Структура репозитория:**
- [`backend/`](backend/) — сервер на Go, REST + WebSocket + cron + APNs
- [`ios/`](ios/) — iOS-клиент SwiftUI (`ios/cstatiWarehouse.xcodeproj`)
- [`Docs/`](Docs/) — подробные доки по фичам и инфраструктуре
- [`Docs/ADR/`](Docs/ADR/) — Architecture Decision Records
- [`scripts/`](scripts/) — нагрузочные тесты, проверка дашборда, очистка комментариев

---

## Содержание

1. [Концепция и ключевые сценарии](#1-концепция-и-ключевые-сценарии)
2. [Глоссарий](#2-глоссарий)
3. [Карта экранов iOS-клиента (по разделам)](#3-карта-экранов-ios-клиента-по-разделам)
4. [Технологический стек](#4-технологический-стек)
5. [Архитектура iOS-клиента](#5-архитектура-ios-клиента)
6. [Архитектура backend](#6-архитектура-backend)
7. [Полный список API-эндпоинтов](#7-полный-список-api-эндпоинтов)
8. [Доменные модели и инварианты](#8-доменные-модели-и-инварианты)
9. [Схема БД и миграции](#9-схема-бд-и-миграции)
10. [Безопасность и ограничения](#10-безопасность-и-ограничения)
11. [Real-time, push, offline](#11-real-time-push-offline)
12. [Smart Expiration Notifications — глубокий разбор](#12-smart-expiration-notifications--глубокий-разбор)
13. [Item Comments System — глубокий разбор](#13-item-comments-system--глубокий-разбор)
14. [Item Reservations — глубокий разбор](#14-item-reservations--глубокий-разбор)
15. [Аналитический дашборд (Overview)](#15-аналитический-дашборд-overview)
16. [Маршрутизация Route Planning](#16-маршрутизация-route-planning)
17. [Локализация](#17-локализация)
18. [Дизайн-слой и UI-компоненты](#18-дизайн-слой-и-ui-компоненты)
19. [Быстрый старт](#19-быстрый-старт)
20. [Тестирование](#20-тестирование)
21. [Конфигурация (env)](#21-конфигурация-env)
22. [Документация по фичам](#22-документация-по-фичам)
23. [Частые задачи → куда смотреть](#23-частые-задачи--куда-смотреть)
24. [Стандарты кода](#24-стандарты-кода)

---

## 1. Концепция и ключевые сценарии

**cstatiWarehouse** — мобильная (iOS) система учёта склада для **студенческих и небольших организационных команд** с ограниченным числом ответственных. Главная боль продукта: «сегодня что-то списали с одного телефона — завтра другой человек думает, что оно ещё есть; еда в холодильнике портится, потому что никто не помнит про срок».

### Что приложение решает

1. **Совместный учёт инвентаря** — несколько человек видят одну и ту же актуальную картину склада организации.
2. **Иерархия товаров** — у одного «логического» товара могут быть **варианты упаковки**: «Сок» → «1 л», «0.5 л». При этом по-прежнему один экран «склад» и одна агрегация литров для отчётности.
3. **Срок годности** — чтобы ничего не пропало:
   - **Серверный cron** делает push'и за 7 дней / 1 день / в день истечения,
   - **Локальные уведомления** дублируют их с интерактивными actions («Использовать», «Отложить»),
   - **Тихие часы** + таймзона + 5 уровней управления — пользователь не получит ночное уведомление.
4. **Коммуникация** — комментарии прямо на позиции с **mentions**, реакциями, real-time через WebSocket.
5. **Бронирование под мероприятия** — не списывать заранее, но защитить остаток от другой команды:
   - бронь = «доступно к списанию = quantity − sum(active reservations)»;
   - бронь принадлежит мероприятию (`event_id`); на экране планирования маршрута можно выбрать событие — список позиций к пикапу заполнится из брони автоматически.
6. **Аналитика** — главный экран показывает KPI организации: тренд остатков, распределение по категориям, top expiring, shelf-risk диаграмма.
7. **Маршрутизация** — собрался забрать партию у держателей? Геокодирование адресов, MapKit-маршрут, ссылка в Яндекс.Карты.

### Целевые сценарии

- **Студенческое движение / клуб:** учитывают канцтовары, реквизит для мероприятий, расходники.
- **Небольшая команда мероприятий:** бронируют коробки с реквизитом под конкретное событие, видят кто-куда-сколько.
- **Маленький стартап / лаборатория:** учёт расходников с ограниченным сроком годности (реактивы, продукты).

---

## 2. Глоссарий

| Термин | Что значит |
|--------|-----------|
| **Item** | Позиция склада. Минимальная единица учёта. Может быть «корневой» или **вариантом** (с `parent_item_id`). |
| **Variant** | Подпозиция — вариант упаковки/объёма существующего Item'а (например «1 л» внутри «Сок»). У группы (родителя с детьми) количество хранится на вариантах. |
| **Measure unit** | Единица измерения: `piece`, `liter`, `milliliter`, `kilogram`, `gram`. По умолчанию — `piece`. |
| **`volume_per_unit`** | Сколько «единиц меры» в одной упаковке. Используется для агрегации (например 6 коробок × 1.5 л = 9 л). |
| **`aggregated_volume_liters`** | Считается на бэкенде для родителя: сумма по литровым/мл-вариантам. |
| **Quantity** | Количество **упаковок**. Для группы — 0 (всё на вариантах). |
| **Archive** | Списание Item'а целиком или частично. Причина обязательна. |
| **`ArchiveReason`** | `usedAtEvent`, `expired`, `disposed`, `lost`, `other`. Для `usedAtEvent` нужно `event_id`, для `other` — текст. |
| **Holder (`heldByUserID`)** | Текущий ответственный за Item. Видно в карточке. |
| **Organization** | «Склад». У пользователя может быть много организаций. Одна **активная** — её данные показываются. |
| **`OrgRole`** | `owner` / `admin` / `member`. См. инварианты в §8. |
| **Personal organization** | Создаётся автоматически при регистрации, нельзя удалить/переименовать/покинуть. |
| **Invite** | Код, по которому новый пользователь вступает в организацию (`POST /organizations/join`). |
| **Event (OrgEvent)** | Мероприятие организации — точка привязки для бронирований и архиваций. |
| **Reservation** | Бронь N упаковок Item'а под событие. Не списывает, но «уменьшает» `available`. |
| **Comment / Reaction** | Тред-комментарий под Item с эмодзи-реакциями. |
| **`ExpirationLevel`** | `firstWarning` (за 7 д), `lastWarning` (за 1 д), `expired` (день в день). |
| **Quiet hours** | Промежуток времени (минуты с начала суток), когда уведомления не приходят. |
| **Activity log** | Лента действий организации (создания, архивации, передачи владения и т.д.). |
| **WebSocket event** | Сообщение от сервера через `/ws` с обновлением (item changed, comment added, reservation changed). |
| **APIClient** | Единый iOS-класс для HTTP. Делает refresh при 401. |
| **Composition root** | Точка сборки зависимостей: iOS — `AppServices`, Backend — `cmd/server/main.go`. |

---

## 3. Карта экранов iOS-клиента (по разделам)

> Каждая сцена — папка [`ios/cstatiWarehouse/Scenes/<Name>/`](ios/cstatiWarehouse/Scenes/) с пятёркой `Assembly + Presenter + Interactor + Router + View` (плюс опц. `Entity` и шиты). Описание UI ниже — что именно видит пользователь и что под капотом.

### 3.1 Authentication / Login
**Файлы:** [`Scenes/Authentication/Login/`](ios/cstatiWarehouse/Scenes/Authentication/Login/).

- **UI:** анимированный градиентный фон, иконка приложения, заголовок «Добро пожаловать», подзаголовок «Войдите в свой аккаунт».
- **Поля** (`GlassTextField`): Email, Password.
- **Кнопки:**
  - «Войти» (`GlassPillButton`),
  - «Войти через Telegram» ([`TelegramLoginButton`](ios/cstatiWarehouse/CoreUI/TelegramLoginButton.swift:1)),
  - Sign in with Apple,
  - «Войти через Google»,
  - линка-переход на Register.
- **Валидация:** email / password проверяются перед отправкой.
- **Поток:** `LoginInteractor` вызывает `authService.login` → `sessionStorage.save` → `Router.navigate(.main)`.
- **Ошибки:** alert «Ошибка» + `errorMessage` в Presenter. Для Telegram, если не настроен — предупреждение `notConfigured`.

### 3.2 Authentication / Register
**Файлы:** [`Scenes/Authentication/Register/`](ios/cstatiWarehouse/Scenes/Authentication/Register/).

- **UI:** градиентный фон, заголовок, **аватар-пикер** (тапаешь круг — открывается `PhotoSourceSheet` с выбором «Камера / Галерея / Удалить»).
- **Поля:** Имя, Фамилия, Email, Password.
- **Live-валидация пароля:** при изменении вызывается `presenter.validatePassword` — отображается список требований (длина, цифры, буквы) с цветными индикаторами.
- **Кнопки:** «Зарегистрироваться», Telegram / Apple / Google, ссылка на Login.
- **Поток:** при наличии аватара сначала `uploadsService.uploadImage` → `authService.register` с URL → сессия + `.main`.
- **Ошибки:** alert + `errorMessage`.

### 3.3 TabBar (корневой контейнер после логина)
**Файл:** [`Scenes/TabBar/TabBarView.swift`](ios/cstatiWarehouse/Scenes/TabBar/TabBarView.swift:11).

- **Три вкладки:**
  1. «Мой склад» (warehouse-сцена),
  2. «Сводка» (Overview / Dashboard),
  3. «Организация» (управление активной),
  *плюс* опционально — «Резервации» / «Маршрут» / «Уведомления» (открываются из других экранов).
- **TabBarChrome** — кастомизация системного UITabBar для плавного «glass»-вида.

### 3.4 Мой склад (MyWarehouse)
**Папка:** [`Scenes/MyWarehouse/`](ios/cstatiWarehouse/Scenes/MyWarehouse/).

#### UI
- **Top bar:** переключатель организации (название + chevron открывает `OrganizationSwitcherSheet`), кнопка профиля (иконка пользователя), кнопка «+» (создание Item).
- **Search bar** + кнопка фильтра (`WarehouseFiltersSheet`).
- **Кнопка «История списаний»** — открывает `ArchiveHistorySheet`.
- **Scope-picker** (только для admin/owner в неперсональной орг.): «Мои» / «Все».
- **Список** позиций, сгруппированных по категориям (с заголовками-секциями):
  - **Item-карточка** (`WarehouseItemCard`): фото, имя, количество, бейдж статуса срока (`ExpirationStatus`), категория, при наличии — бейдж «Держатель». Длинный тап открывает `ItemDetailSheet`.
  - **Группа с вариантами:** карточка-родитель + раскрывающийся список вариантов; у родителя количество скрыто, у варианта — отдельные степпер/архивация.
- **Pull-to-refresh** перезапрашивает позиции.
- **Empty state** меняется по контексту: «Пусто», «Нет результатов поиска», «Все списано».
- **Skeleton list** — пока идёт первая загрузка.
- **Passive Network Banner** ([`PassiveNetworkBanner`](ios/cstatiWarehouse/CoreUI/PassiveNetworkBanner.swift:1)) — баннер «нет сети, показываем кеш» с кнопками retry / dismiss.

#### Сценарии
- **Создание:** «+» → `ItemEdit` в режиме `.create`.
- **Редактирование:** свайп / тап «edit» → `ItemEdit` в режиме `.edit(item)`.
- **Создание варианта:** на родителе кнопка «Добавить вариант» → `ItemEdit` в режиме `.createVariant(parent:)`.
- **Архивация:** свайп / тап → `ArchiveReasonPickerView` (выбор причины и количества) → подтверждение.
- **Hard delete:** только owner/admin, требует подтверждения.
- **Переключатель орг.** (`OrganizationSwitcherSheet`):
  - список организаций пользователя,
  - активная отмечена,
  - две формы внизу: «Создать» (имя) и «Вступить по коду» (инвайт-код),
  - после выбора Interactor сохраняет UUID в `ActiveOrganizationStorage` и перезагружает список.

#### Под капотом
[`MyWarehouseInteractor`](ios/cstatiWarehouse/Scenes/MyWarehouse/MyWarehouseInteractor.swift):

1. `resolveActiveOrganization` — `GET /organizations` → выбор активной (сохранённый UUID > первая личная > первая в списке).
2. `fetchActiveItems(orgID, scope: .mine | .all)`.
3. `fetchCategories` — для секций.
4. При scope-смене Interactor запоминает кэш по scope, чтобы не перезапрашивать.

[`WarehouseFilterEngine`](ios/cstatiWarehouse/Scenes/MyWarehouse/WarehouseFilterEngine.swift) и [`WarehouseSortEngine`](ios/cstatiWarehouse/Scenes/MyWarehouse/WarehouseSortEngine.swift) — изолированные функции, у которых есть собственные unit-тесты.

### 3.5 ItemEdit (создание / редактирование позиции)
**Папка:** [`Scenes/ItemEdit/`](ios/cstatiWarehouse/Scenes/ItemEdit/).

#### UI
- **Header:** заголовок («Новая позиция» / «Редактировать» / «Новый вариант»).
- **Form:**
  - **Категория** — chip-flow (`FlowLayout` + `GlassChip`); тап на «+» открывает `newCategorySheet` для inline-создания.
  - **Название**, **описание** (`GlassTextField` + `glassTextEditor`).
  - **Photo field** — тап → `PhotoSourceSheet` (камера / галерея / удалить).
  - **Holder field** — тап открывает `HolderPickerSheet` со списком участников организации.
  - **Measure unit picker** — пять единиц.
  - **`volume_per_unit`** — текстовое поле, появляется когда `measureUnit != .piece` (для литров/мл/кг/г).
  - **Quantity field** — степпер (–/+) с валидацией; для родителя-группы скрывается.
  - **Expiration field** — `DrumDatePicker` (русская локаль), допускает «без срока годности».
  - **Toggle «Несколько вариантов упаковки»** (только в режиме create) — превращает создаваемый Item в **родителя**, на который будут вешаться варианты.
- **Footer:** «Сохранить» (с indicator), «Удалить» (только в edit, owner/admin).

#### Поток
- При сохранении: если есть новое фото — `uploadsService.uploadImage` → `createItem`/`updateItem` с image URL.
- В теле уходят: `parent_item_id`, `variant_label`, `measure_unit`, `volume_per_unit` (если задано).
- Колбэк наверх: `editCompleted(result:)` где `result` ∈ `.created(item)`, `.updated(item)`, `.deleted(id)`.

### 3.6 ItemDetailSheet
**Файл:** [`Scenes/MyWarehouse/ItemDetailSheet.swift`](ios/cstatiWarehouse/Scenes/MyWarehouse/ItemDetailSheet.swift:10).

- **Modal sheet** при тапе на карточку.
- **Header:** название, статус срока (бейдж), категория, кнопка закрытия.
- **Изображение** (если есть) — `RemoteImageView` с кешем.
- **Details card** — иконки + label + value: «Количество», «Единица», «Объём за упаковку», «Адрес», «Держатель», «Создано», «Обновлено».
- **Expiration row** с цветным бейджем по `ExpirationStatus`.
- **Кнопки:** «Редактировать», «Резервировать» (открывает `Reservations` в режиме «новая бронь под этот Item»), «Комментарии» (`CommentsView`), «Списать» (`ArchiveReasonPickerView`).

### 3.7 ArchiveHistorySheet
**Файл:** [`Scenes/MyWarehouse/ArchiveHistorySheet.swift`](ios/cstatiWarehouse/Scenes/MyWarehouse/ArchiveHistorySheet.swift:1).

- Список **`ArchiveEvent`** организации: дата, кто списал, какая позиция, количество, причина (с локализованным переводом), привязанное мероприятие (если есть).
- Поддерживает пагинацию через `?limit&offset`.

### 3.8 ArchiveReasonPickerView
**Файл:** [`Scenes/MyWarehouse/ArchiveReasonPickerView.swift`](ios/cstatiWarehouse/Scenes/MyWarehouse/ArchiveReasonPickerView.swift:1).

- Степпер количества к списанию (от 1 до текущего `quantity`).
- Радио-выбор причины: «На мероприятии», «Истёк срок», «Утилизировано», «Потеряно», «Другое».
- Если «На мероприятии» — picker со списком `OrgEvent` или inline-создание нового.
- Если «Другое» — обязательное текстовое поле комментария.
- Кнопка «Списать» с loading-индикатором.

### 3.9 Organization (вкладка «Организация»)
**Папка:** [`Scenes/Organization/`](ios/cstatiWarehouse/Scenes/Organization/).

#### UI
- **Header:** название организации + бейдж роли пользователя.
- **Info card:** ID организации (для дебага / копирования), дата создания, количество участников.
- **«Управлять приглашениями»** (только для `canManageMembers`) — открывает `InvitesSheet`:
  - список активных инвайтов с кодом, истечением, использованиями;
  - кнопка «Создать новый инвайт» (выбор TTL и max-uses).
- **Members section:** список участников с аватарами и ролями.
  - У admin/owner — long-press на участника даёт меню: «Сменить роль», «Удалить из организации», «Передать владение» (только owner).
- **Manage section:**
  - «Мероприятия» (`EventsSheet`),
  - «Категории» (`CategoriesSheet`),
  - «Лента активности» (`ActivitySheet`),
  - «Переименовать» (только owner).
- **Danger section:**
  - «Покинуть организацию» (с confirmation; нельзя для owner — нужно сначала передать владение, нельзя для personal),
  - «Удалить организацию» (только owner; с confirmation).

#### Шиты
- **`InvitesSheet`** — управление инвайтами.
- **`EventsSheet`** — список `OrgEvent` (создать, переименовать, удалить).
- **`CategoriesSheet`** — категории организации (`OrgCategory`); добавлять / удалять.
- **`ActivitySheet`** — лента активности (создание/архивация/изменение/добавление участника/...).
- **`renameSheet`** — переименование организации.

#### Под капотом
[`OrganizationInteractor`](ios/cstatiWarehouse/Scenes/Organization/OrganizationInteractor.swift):
1. `loadSummary` → `fetchOrganization(activeID)`,
2. `fetchMembers`,
3. для `canManageMembers` — `loadInvites`.

После leave/delete сбрасывается `ActiveOrganizationStorage`. На `viewDidAppear` сравнивается `activeOrganizationID` с `lastActiveOrgID` и при смене делается `refresh()`.

### 3.10 Settings (вкладка «Настройки» / профиль)
**Папка:** [`Scenes/Settings/`](ios/cstatiWarehouse/Scenes/Settings/).

#### UI
- **Header**: «Профиль».
- **Avatar button** — тап → `PhotoSourceSheet` (камера / галерея / удалить).
- **Поля:** Имя, Фамилия (`GlassTextField`).
- **«Сохранить»** — кнопка активна только при наличии изменений (`hasPendingChanges`).
- **«Уведомления»** — линка на `NotificationPreferencesView`.
- **«Выйти»** — destructive button.

#### Поток
- Сохранение: при наличии нового аватара — `uploadsService.uploadImage` → `PATCH /auth/me` с патчем (имя/фамилия/avatar_url; для удаления аватара — null через `NullableString`).
- Logout: `SettingsInteractor.logout` чистит `sessionStorage` и `ActiveOrganizationStorage`, Router → `popToRoot()` к Login.

### 3.11 NotificationPreferences
**Папка:** [`Scenes/NotificationPreferences/`](ios/cstatiWarehouse/Scenes/NotificationPreferences/).

#### UI
- **Header subtitle** — описание, что эти настройки управляют push-уведомлениями о сроке годности.
- **Levels section** — для каждого `ExpirationLevel` (`firstWarning`, `lastWarning`, `expired`) — `Toggle` с локализованным названием и описанием.
- **Quiet hours section** — два time-picker'а (start / end). Внутри хранится в минутах от 00:00; конвертация в `Date` для UI.
- **Timezone section** — picker IANA TZ (по умолчанию текущая).
- **Saving indicator** — мини-иконка «сохраняется...» при выполнении PATCH.

#### Поток
- На `viewDidLoad` `presenter.load()` → `notificationPreferencesService.fetch()`.
- На каждый toggle / picker change — `save(patch:)` (debounce внутри) → `PUT /notifications/preferences`.

### 3.12 Overview (Dashboard)
**Папка:** [`Scenes/Overview/`](ios/cstatiWarehouse/Scenes/Overview/).

#### UI
- **Header** — название организации, период метрик.
- **Empty state** для пустой / отсутствующей орг.
- **Loading** — skeleton.
- **Map route teaser card** — мини-карточка-приглашение на `RoutePlanning`.
- **Metrics cards** — KPI плитки (всего позиций, в процессе истечения, без держателя, активные брони).
- **Shelf risk chart** ([`OverviewAnalyticsBuilder`](ios/cstatiWarehouse/Scenes/Overview/OverviewAnalyticsBuilder.swift), [`shelfRiskRows`](ios/cstatiWarehouse/Scenes/Overview/OverviewAnalyticsModels.swift)) — диаграмма «Свежие / Скоро истекут / Истекают сегодня / Просрочены».
- **Category distribution** — Swift Charts pie/donut.
- **Stock trend** — Swift Charts line по дням.
- **Expiring items list** — топ-N с самым близким сроком; тап ведёт на ItemDetailSheet.
- **Passive Network Banner** — при использовании кеша.

#### Под капотом
- `OverviewInteractor.loadDashboard` → `GET /analytics/dashboard`.
- `OverviewAnalyticsBuilder` — чистая функция, превращает DashboardMetrics в `OverviewAnalyticsSnapshot` (для разделения данных и UI).

### 3.13 Comments (тред под Item)
**Папка:** [`Scenes/Comments/`](ios/cstatiWarehouse/Scenes/Comments/).

#### UI
- **Список** комментариев (root + replies в виде уровней).
- Каждый **commentBlock**:
  - аватар автора, имя, относительное время (`RelativeDateTimeFormatter`),
  - текст с подсвеченными mentions (`@username`),
  - **reactionsRow** — горизонтальная лента эмодзи-реакций с счётчиками; своя реакция — выделена,
  - **actionsRow** — «Ответить», «Реакция» (popover с эмодзи), кнопка контекстного меню для автора (Edit / Delete).
- **Composer (внизу):**
  - заголовок «Ответить @<имя>» / «Редактировать» — если в режиме reply / edit, с кнопкой отмены,
  - text editor (`glassTextEditor`),
  - выпадашка mentions: при наборе `@` показывается список участников орг.;
  - кнопка «Отправить» (активна только при непустом тексте).
- **Empty state** — «Пока никто не оставил комментариев».
- **Failed state** — баннер с retry.

#### Под капотом
[`CommentsPresenter`](ios/cstatiWarehouse/Scenes/Comments/CommentsPresenter.swift):
- `state: .idle / .loading / .failed / .loaded(comments)`,
- оптимистичный UI для реакций (`applyReactionOptimistically`),
- mentions парсятся через regex (`@[\w.]+`) и резолвятся по списку участников орг.,
- при изменении приходит сообщение по WebSocket → Presenter обновляет ленту.

### 3.14 Reservations
**Папка:** [`Scenes/Reservations/`](ios/cstatiWarehouse/Scenes/Reservations/).

#### UI
- **Header** с метриками: всего активных, истекают, fulfilled, cancelled.
- **Filter chips** ([`Filter`](ios/cstatiWarehouse/Scenes/Reservations/ReservationsPresenter.swift:19)) — `all`, `active`, `fulfilled`, `cancelled`, `expired`.
- **Reservation card:**
  - название Item'а + количество,
  - бейдж статуса (цвет по `ReservationStatus`),
  - имя мероприятия (если есть),
  - кто и когда забронировал,
  - дата истечения / относительное время,
  - actions row: «Использовать» (fulfill), «Отменить» (открывает `CancelReservationSheet` с обязательным комментарием).
- **Empty state.**
- **Failed state.**

#### `CreateReservationSheet`
- **Quantity stepper** (–/+) с валидацией (не превышает доступно).
- **Event section** — chip-flow `eventChipsFlow`:
  - чипы со списком событий организации,
  - чип «+» открывает `newEventSheet` для inline-создания.
- **Expiry section** — toggle «Бессрочно» / `DrumDatePicker` для `expires_at`.
- **Notes** — `glassTextEditor` (опционально).
- **Submit** с loading.

#### `CancelReservationSheet`
- Текст: «Отменить бронь "<имя>"?».
- Обязательный текст причины.
- Submit destructive.

#### Под капотом
[`ReservationsPresenter`](ios/cstatiWarehouse/Scenes/Reservations/ReservationsPresenter.swift):
- `loadMembers`, `loadEvents`, `reload`, `reloadAvailability`,
- `presentCreate(item:)`, `submitCreate`, `cancel(reservation, reason:)`, `fulfill(reservation)`,
- `createNewEvent(name:)` — inline создание мероприятия из чип-пикера.

### 3.15 RoutePlanning
**Папка:** [`Scenes/RoutePlanning/`](ios/cstatiWarehouse/Scenes/RoutePlanning/).

#### UI
- **Header copy** — описание, как работает планировщик.
- **Transport picker** — авто / пешком / общественный транспорт (для расчёта маршрута через MapKit).
- **Address fields** — start (опц.) и destination (с inline-геокодингом, debounced).
- **Event quick pick section** — chip-flow событий организации; при выборе авто-наполняет позиции к пикапу из активных бронирований события (`applyEventReservations`).
- **Items section** — список позиций с степпером количества (можно перебить значение, выставленное событием).
- **Build button** — собирает маршрут через MapKit.
- **Map section** — `Map` со стопами + полилинией.
- **Stops section** — карточки точек с адресом, перечнем позиций и индикатором статуса.
- **Yandex link section** — кнопка «Открыть в Яндекс.Картах» с готовым URL.

#### Под капотом
[`RoutePlanningInteractor`](ios/cstatiWarehouse/Scenes/RoutePlanning/RoutePlanningInteractor.swift):
- `loadEvents()` → `eventsService.list`,
- `applyEventReservations(eventID:)` → берёт активные брони события, мапит на текущие позиции; если бронь не найдена среди позиций — попадает в `skippedNames`,
- `loadPickupItems()` → корневые активные позиции,
- `buildRoute(...)` → `geocodeSerial` адресов держателей → `MKDirections.calculate` → assemble в `RoutePlanningMapModel`.

### 3.16 OrganizationSwitcherSheet
- Открывается из top bar склада или из выбора активной орг. при первом запуске.
- **Поля:** список организаций (с иконками личной/общей, чекмарком на активной), формы «Создать» и «Вступить по коду».
- **Reactivity:** при выборе сразу применяется (Interactor сохраняет UUID, склад перезагружается); при создании/join — добавляется и активируется.

### 3.17 PhotoSourceSheet
**Файл:** [`CoreUI/ImagePicker/PhotoSourceSheet.swift`](ios/cstatiWarehouse/CoreUI/ImagePicker/PhotoSourceSheet.swift).

- Простой sheet с тремя кнопками: «Камера» (UIImagePicker .camera), «Галерея» (PHPickerViewController), «Удалить» (если allowed).

---

## 4. Технологический стек

### Backend
| Область | Выбор |
|---------|-------|
| Язык | Go 1.22+ |
| HTTP | стандартная `net/http` (Go 1.22 routing с path values) |
| БД | PostgreSQL 16, драйвер `pgx/v5` |
| Миграции | `goose` |
| Аутентификация | JWT HS256, bcrypt; JWKS-валидация (Telegram / Google / Apple) |
| WebSocket | `gorilla/websocket` |
| Push | APNs (HTTP/2 JWT) |
| Файлы | S3-совместимое хранилище |
| Архитектура | Clean / Ports & Adapters; CQRS-разделение репозиториев |

### iOS
| Область | Выбор |
|---------|-------|
| UI | SwiftUI |
| Состояние | `@Observable` Presenter + `@Bindable` во View |
| Concurrency | Swift 6 strict, `@MainActor` для UI |
| Сеть | `URLSession` через единый [`APIClient`](ios/cstatiWarehouse/Services/Network/APIClient.swift:18) |
| Карты | MapKit + диплинк в Яндекс.Карты |
| Графики | Swift Charts |
| Анимации | Lottie (splash) |
| Telegram | пакет `TelegramLogin` |
| OAuth | Apple AuthenticationServices + Google Sign-In |
| Tests | Swift Testing (`@Suite`, `@Test`, `#expect`) + XCTest (UI) |
| Persistence | `UserDefaults` (сессия, активная орг.) + SwiftData (offline-кеш) |

---

## 5. Архитектура iOS-клиента

### 5.1 VIPER-подобный паттерн
**Assembly → Presenter → Interactor → Router → SwiftUI View**

| Слой | Ответственность |
|------|-----------------|
| **View** | UI, биндинги к Presenter, действия (`…Tapped`, `…Requested`). **Не** делает навигацию мимо Router. |
| **Presenter** | состояние, форматирование, UI-модели, реакция на колбэки Interactor; `@Observable`. |
| **Interactor** | бизнес-операции, вызов сервисов; `weak var presenter`; `[weak self]` в async. |
| **Router** | **только** навигация через `AppCoordinatorProtocol`. |
| **Assembly** | связывание зависимостей; реализации тянет из `AppServices`. |

Старт сцены: `presenter.viewDidLoad()` из `.onAppear` — **не** из `init` Presenter.

### 5.2 Точка входа
1. [`CstatiWarehouseApp`](ios/cstatiWarehouse/App/CstatiWarehouseApp.swift:14) — тёмный фон до первого кадра, опц. `TelegramLogin.configure`, регистрация notification actions, `RootView` в `WindowGroup`, `onOpenURL` → `TelegramLogin.handle`.
2. **`RootView`** — splash ~3.5 c (Lottie) поверх `CoordinatorView`, координатор успевает отрисоваться в фоне.
3. [`CoordinatorView`](ios/cstatiWarehouse/Coordinator/CoordinatorView.swift) — `NavigationStack` + `AppCoordinator.path`. Корень всегда `LoginAssembly`. Если `sessionStorage.isLoggedIn` — в path сразу добавляется `.main`.
4. После логина — `TabBarView` с тремя вкладками.

### 5.3 Координатор и маршруты
[`AppCoordinator`](ios/cstatiWarehouse/Coordinator/AppCoordinator.swift):
- `AppRoute`: `login`, `register`, `main`, `profile`,
- держит `NavigationPath` и реализует `navigate(_:)` / `pop()` / `popToRoot()`.

`navigationDestination(for: AppRoute.self)` → соответствующая Assembly.

`MainTabCoordinator` — отдельный объект вкладок (вкладка «Мой склад» может пушнуть focus-фильтр на конкретной категории).

**Logout:** `SettingsInteractor.logout` чистит сессию + активную орг → `popToRoot()` к Login.

### 5.4 Композиция зависимостей
[`AppServices`](ios/cstatiWarehouse/Services/AppServices.swift:10) — единственный composition root для прода:
- единый [`APIClient(sessionStorage:)`](ios/cstatiWarehouse/Services/Network/APIClient.swift:18),
- `UserDefaultsUserSessionStorage`, `UserDefaultsActiveOrganizationStorage`,
- WebSocket service (общий, лениво коннектится),
- фабрики всех сервисов: `authService()`, `warehouseService()`, `commentsService()`, `reservationsService()`, `eventsService()`, `analyticsService()`, `notificationPreferencesService()`, `pushNotificationService`, `shelfLifeNotifier` и т.д.

В тестах подставляются `Mock*` из [`cstatiWarehouseTests/TestDoubles/`](ios/cstatiWarehouseTests/TestDoubles/), в `#Preview` — [`Services/Preview/PreviewServices.swift`](ios/cstatiWarehouse/Services/Preview/PreviewServices.swift).

### 5.5 Сетевой клиент (правила обязательны)
[`APIClient`](ios/cstatiWarehouse/Services/Network/APIClient.swift:18):

- **JSON:** `keyDecodingStrategy = .convertFromSnakeCase` + `keyEncodingStrategy = .convertToSnakeCase`.
  - **Никогда** не использовать явные `CodingKeys` в snake_case — двойная конвертация ломает декодирование. Если для поля нужен другой ключ, использовать **camelCase**-имя в Swift и менять на сервере.
- **Даты:** ISO8601 с дробной частью и без (два форматтера-фолбэка), оба статически закешированы.
- **Auth:** `Authorization: Bearer <access>` для `authenticated: true`.
- **401 → refresh:**
  - очередь `refreshQueue`, семафор,
  - синхронный вызов `/auth/refresh`,
  - обновление токенов в `sessionStorage`,
  - **ровно одна** повторная попытка исходного запроса; при провале — `clear()` сессии и `.unauthorized`.
- **Retry на транспортных ошибках:** до 3 попыток с экспоненциальной задержкой.
- **completion** всегда на main (`completeOnMain`).
- **Upload:** `upload(...)` multipart, тот же pipeline с токеном.

`APIError` → доменные ошибки сервисов (`AuthError`, `WarehouseError`, `CommentsError`, `ReservationsError`, …).

### 5.6 Структура папок iOS
```
ios/cstatiWarehouse/
├── App/                          точка входа SwiftUI App + AppDelegate + Splash
├── Coordinator/                  AppCoordinator, MainTabCoordinator, CoordinatorView
├── Scenes/
│   ├── Authentication/           Login + Register
│   ├── MyWarehouse/              склад: список + переключатель + архив + filters/sort engines
│   ├── ItemEdit/                 создание/редактирование позиции (+ варианты)
│   ├── Organization/             вкладка организации (members/invites/events/categories/activity)
│   ├── Settings/                 профиль + ссылка на NotificationPreferences + logout
│   ├── Overview/                 аналитический дашборд (KPI + Charts + shelf-risk)
│   ├── Comments/                 тред комментариев под Item
│   ├── Reservations/             резервирование (список + создание + cancel/fulfill)
│   ├── RoutePlanning/            маршрут пикапа по мероприятию (MapKit + Яндекс)
│   ├── NotificationPreferences/  настройки уровней + тихих часов
│   └── TabBar/                   корневой таб-бар
├── Services/                     Api*Service + протоколы + моки
├── Persistence/                  SwiftData offline-кеш + ключи
├── Entity/                       доменные структуры (Item, Organization, ItemReservation, ItemComment, …)
├── CoreUI/                       glass-компоненты
├── Extensions/                   Date / String / …
├── Resources/Localization/       ru.lproj + en.lproj + L10n
└── Docs/                         iOS-стратегии: BackgroundSync, CacheInvalidation, ErrorHandling
```

---

## 6. Архитектура backend

### 6.1 Слои (Clean / Ports & Adapters)

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
│   │   ├── repo/           pgx-реализации портов
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
└── docs/                   архитектурные доки (CQRS, WebSocket, Observability)
```

### 6.2 Правило зависимостей
- `domain` ничего не знает про HTTP / SQL / JSON.
- `usecase` зависит только от `domain` и собственных портов.
- `adapter/*` реализуют порты и работают с pgx / HTTP / WebSocket.
- `infra/*` — физические инструменты.
- `cmd/server/main.go` — единственное место, где всё собирается.

### 6.3 Порты usecase
[`internal/usecase/ports.go`](backend/internal/usecase/ports.go:1) объявляет интерфейсы:
- `UserRepository`, `OrganizationRepository`, `MemberRepository`, `InviteRepository`,
- `ItemReadRepository`, `ItemWriteRepository` (CQRS), `CategoryRepository`, `EventRepository`, `ActivityRepository`,
- `CommentRepository`, `ReservationRepository`, `ExpirationNotificationRepository`,
- `SessionRepository` (refresh tokens), `PushTokenRepository`,
- `Hasher`, `TokenIssuer`, `Clock`,
- `TelegramVerifier`, `GoogleVerifier`, `AppleVerifier`,
- `Pusher` (APNs).

### 6.4 Use cases (структура)
- [`auth.go`](backend/internal/usecase/auth.go:1) — Register, Login, Telegram, Google, Apple, Refresh, Logout, Me, UpdateProfile.
- [`warehouse.go`](backend/internal/usecase/warehouse.go:1) — Items CRUD + Archive + Categories + ArchiveEvents.
- [`organizations.go`](backend/internal/usecase/organizations.go:1) — CRUD, members, invites, transfer, leave.
- [`events.go`](backend/internal/usecase/events.go:1) и [`categories.go`](backend/internal/usecase/categories.go:1) — управление мероприятиями и категориями организации.
- [`activity.go`](backend/internal/usecase/activity.go:1) — лента активности.
- [`analytics.go`](backend/internal/usecase/analytics.go:1) — `GetDashboard` (агрегации + кеширование).
- [`comments.go`](backend/internal/usecase/comments.go:1) — комментарии + реакции + парсинг mentions + push-уведомления упомянутым.
- [`reservations.go`](backend/internal/usecase/reservations.go:1) — резервирование, доступность, lifecycle.
- [`expiration_notifications.go`](backend/internal/usecase/expiration_notifications.go:1) — preferences + scan + snooze.

### 6.5 CQRS read/write
> [`backend/docs/CQRS-Repository-Split.md`](backend/docs/CQRS-Repository-Split.md).

Read и write репозитории — отдельные интерфейсы и pgx-реализации. Read-side можно направить в read-replica.

### 6.6 Маппинг ошибок
[`pkg/apierror/mapper.go`](backend/pkg/apierror/mapper.go:1) — единая точка перевода доменных ошибок (`domain.ValidationError`, `domain.NotFoundError`, `domain.ForbiddenError`, `ItemVersionConflictError`, …) в HTTP-коды + JSON-тело.

### 6.7 Middleware (порядок)
[`router.go`](backend/internal/adapter/httpapi/router.go:1):
1. `securityHeadersMiddleware` — `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security`.
2. `recoverMiddleware` — паника → 500, процесс не падает, стек попадает в лог.
3. `loggingMiddleware` — request-id, method, path, status, latency, user-id (если известен).
4. `corsMiddleware` — whitelisted-origins из env, `OPTIONS` short-circuit.
5. `authRateLimitMiddleware` — токен-бакет на IP для `/api/v1/auth/*` (защита от brute-force).
6. `authMiddleware` — JWT HS256, кладёт `userID` в контекст ([`middleware.go`](backend/internal/adapter/httpapi/middleware.go:1)).
7. `userRateLimitMiddleware` — токен-бакет на пользователя для основной API.

---

## 7. HTTP API — полный каталог эндпоинтов

База: `/api/v1`. Авторизация: `Authorization: Bearer <access_token>` (кроме `/auth/*`). Все ответы — JSON, тела ошибок: `{ "error": "code", "message": "human-readable" }`.

### 7.1 Auth ([`auth_handler.go`](backend/internal/adapter/httpapi/auth_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `POST` | `/auth/register` | Регистрация (email + password). Возвращает `access_token` + `refresh_token` + `user`. |
| `POST` | `/auth/login` | Логин email/password. |
| `POST` | `/auth/refresh` | Обмен `refresh_token` → новая пара токенов (rotation). |
| `POST` | `/auth/logout` | Инвалидация refresh-токена. |
| `POST` | `/auth/oauth/telegram` | Telegram Login: проверка подписи `hash` + дата. |
| `POST` | `/auth/oauth/google` | Google Sign-In: верификация `id_token` через JWKS. |
| `POST` | `/auth/oauth/apple` | Apple Sign In: верификация `identity_token` через JWKS. |

### 7.2 Items / Warehouse ([`warehouse_handler.go`](backend/internal/adapter/httpapi/warehouse_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/items?org_id=&scope=active|archive&search=&category=` | Список вещей (root + варианты). |
| `POST` | `/items` | Создание (root или вариант через `parent_item_id`). |
| `GET` | `/items/{id}` | Детальная карточка. |
| `PATCH` | `/items/{id}` | Частичное обновление. Optimistic lock через `If-Match: <updated_at_iso>`; конфликт → 412. |
| `POST` | `/items/{id}/archive` | Софт-архив с `reason` (`used`/`expired`/`damaged`/`lost`/`other`). |
| `POST` | `/items/{id}/restore` | Восстановление из архива. |
| `DELETE` | `/items/{id}` | Hard-delete (только owner/admin, без активных резервов). |
| `GET` | `/organizations/{id}/archive-events` | История архивных событий. |
| `GET` | `/organizations/{id}/categories` | Используемые категории. |

### 7.3 Organizations ([`organizations_handler.go`](backend/internal/adapter/httpapi/organizations_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/organizations` | Все организации текущего пользователя. |
| `POST` | `/organizations` | Создать организацию (creator → owner). |
| `PATCH` | `/organizations/{id}` | Переименовать (owner/admin). |
| `GET` | `/organizations/{id}/members` | Список участников + профили. |
| `PATCH` | `/organizations/{id}/members/{userID}` | Сменить роль (`viewer`/`member`/`admin`/`owner`). |
| `DELETE` | `/organizations/{id}/members/{userID}` | Удалить участника (или leave self). |
| `POST` | `/organizations/{id}/invites` | Сгенерировать invite-код. |
| `POST` | `/organizations/join` | Присоединиться по коду (`{ code }`). |
| `POST` | `/organizations/{id}/transfer` | Передать ownership другому участнику. |

### 7.4 Events / Categories ([`events_handler.go`](backend/internal/adapter/httpapi/events_handler.go:1), [`categories_handler.go`](backend/internal/adapter/httpapi/categories_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/organizations/{id}/events` | Список событий организации. |
| `POST` | `/organizations/{id}/events` | Создать событие. |
| `PATCH` | `/events/{id}` | Переименовать. |
| `DELETE` | `/events/{id}` | Удалить (резервации с этим event_id обнуляют ссылку). |
| Аналогично | `/organizations/{id}/categories/*` | CRUD категорий. |

### 7.5 Comments ([`comments_handler.go`](backend/internal/adapter/httpapi/comments_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/items/{id}/comments` | Тред с реакциями и mentions (вложенность через `parent_comment_id`). |
| `POST` | `/items/{id}/comments` | Создать (`text`, опц. `parent_comment_id`, `mentions: [user_id]`). |
| `PATCH` | `/comments/{id}` | Редактировать (только автор). Сервер пересчитывает mentions через SQL-функцию. |
| `DELETE` | `/comments/{id}` | Удалить (автор / admin / owner). Каскадно удаляются ответы. |
| `POST` | `/comments/{id}/reactions` | Поставить реакцию (`type`: `thumbs_up`/`thumbs_down`/`heart`/`laugh`/`party`/`eyes`). |
| `DELETE` | `/comments/{id}/reactions/{type}` | Убрать свою реакцию. |

### 7.6 Reservations ([`reservations_handler.go`](backend/internal/adapter/httpapi/reservations_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/items/{id}/reservations?status=` | Резервы по вещи. |
| `GET` | `/organizations/{id}/reservations?status=` | Резервы по организации (для экрана «Резервы»). |
| `GET` | `/items/{id}/availability` | Доступное количество (`total - active_reserved`). |
| `POST` | `/items/{id}/reservations` | Создать (`quantity`, `event_id?`, `expires_at?`, `note?`). |
| `POST` | `/reservations/{id}/fulfill` | Перевести в `fulfilled` + автоматически списать со склада. |
| `POST` | `/reservations/{id}/cancel` | Отменить (`reason`). |

Lifecycle: `active → fulfilled` или `active → cancelled` или `active → expired` (по TTL фоновым джобом).

### 7.7 Analytics ([`analytics_handler.go`](backend/internal/adapter/httpapi/analytics_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/organizations/{id}/dashboard` | Метрики: total/in-stock/archived/reserved, top categories, expiring soon, низкий остаток. Кеш в памяти ~60s. |

### 7.8 Notifications / Preferences ([`expiration_notifications_handler.go`](backend/internal/adapter/httpapi/expiration_notifications_handler.go:1))
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/notifications/preferences` | Текущие настройки пользователя. |
| `PATCH` | `/notifications/preferences` | Обновить (`first_warning_enabled`, `last_warning_enabled`, `expired_enabled`, `quiet_hours_start_min`, `quiet_hours_end_min`, `timezone`). |
| `POST` | `/notifications/snooze` | Заглушить уведомления для item на `duration` (формат Go `time.Duration` строкой). |
| `POST` | `/devices` | Регистрация APNs-токена устройства. |

### 7.9 Activity / Uploads / WS
| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/organizations/{id}/activity` | Лента активности (создание/изменение/архив/восстановление вещи, резервы). |
| `POST` | `/uploads/photo` | Multipart upload вещи (валидация MIME, ресайз/реcompression, S3/локальный диск). |
| `GET` | `/ws?token=...` | WebSocket-канал ([`websocket/hub.go`](backend/internal/adapter/websocket/hub.go:1)). Сообщения: `item.created/updated/archived/deleted`, `reservation.*`, `comment.*`. |

---

## 8. Доменные модели и инварианты

### 8.1 Item ([`backend/internal/domain/item.go`](backend/internal/domain/item.go:1), [`ios/.../Entity/Item.swift`](ios/cstatiWarehouse/Entity/Item.swift:1))
Поля: `id`, `organization_id`, `name`, `description`, `category`, `holder_user_id`, `parent_item_id`, `measure_unit` (`piece`/`kg`/`liter`/...), `volume_per_unit`, `quantity`, `expiration_date`, `image_url`, `status` (`in_stock`/`archived`), `archive_reason`, `archived_at`, `created_at`, `updated_at`.

Инварианты:
- root и варианты разделены через `parent_item_id`. У варианта `category` наследуется от родителя (валидация на сервере).
- `quantity >= 0`, у root с детьми сервер не редактирует количество напрямую — только сумма по детям.
- Архив root возможен только если у всех живых детей `quantity = 0` ([`item_repo.go`](backend/internal/adapter/repo/item_repo.go:126)).
- Optimistic concurrency: PATCH требует `updated_at` совпадающий с базой; иначе `ItemVersionConflictError` → 412.

### 8.2 Organization & Roles ([`organization.go`](backend/internal/domain/organization.go:1))
- Роли: `owner` > `admin` > `member` > `viewer`.
- `viewer` — read-only, `member` — мутации без управления участниками, `admin` — + участники + роли (кроме owner), `owner` — всё.
- Личная организация (`is_personal=true`) создаётся при регистрации, не удаляется, owner не может выйти.
- Передача владения через `/transfer` — единственный способ сменить owner.

### 8.3 Reservation lifecycle ([`reservation.go`](backend/internal/domain/reservation.go:1))
- Статусы: `active`/`fulfilled`/`cancelled`/`expired`.
- При `Create` сервер проверяет `available = total - SUM(active.quantity)` ([`reservations.go`](backend/internal/usecase/reservations.go:1)).
- `Fulfill` атомарно: списывает `quantity` со склада + статус `fulfilled`.
- `Cancel` принимает текстовый `reason`.
- `event_id` — опциональная привязка к событию (для группировки в UI и Route Planning).
- Фоновый джоб помечает `expired`, когда `expires_at < now AND status='active'`.

### 8.4 Comments ([`comment.go`](backend/internal/domain/comment.go:1))
- Поля: `id`, `item_id`, `author_id`, `parent_comment_id`, `text`, `mentions: [uuid]`, `created_at`, `updated_at`.
- Реакции: 6 типов (`thumbs_up`/`thumbs_down`/`heart`/`laugh`/`party`/`eyes`), `(comment_id, user_id, type)` уникален.
- Mentions парсятся SQL-функцией из миграции `00023` (формат `@username`).
- При создании/редактировании всем упомянутым отправляется push (если разрешено в preferences).

### 8.5 Smart Expiration ([`expiration_notifications.go`](backend/internal/usecase/expiration_notifications.go:1))
- Уровни: `first_warning` (за `thresholdDays`), `last_warning` (за меньший порог), `expired` (после).
- Cron-сканер пробегает items с `expiration_date IS NOT NULL`, сверяется с `expiration_notifications` (anti-duplication) и preferences.
- Дедупликация: `(item_id, level, user_id)` уникальна; уже отправленное не повторяется.
- Quiet hours: окно «не беспокоить» в локальной TZ пользователя.
- Snooze: запись `snoozed_until` для конкретного item.

---

## 9. БД-схема и миграции

`backend/migrations/00001..00025_*.sql` (goose). Сводная таблица:

| № | Файл | Что вводит |
| --- | --- | --- |
| 00001 | `init` | `users`, базовые расширения (`uuid-ossp`/`pgcrypto`). |
| 00002 | `organizations` | `organizations` + `organization_members(role)`. |
| 00003 | `items` | основная таблица items. |
| 00004 | `archive_events` | лог архивных операций. |
| 00005 | `categories` | категории организаций. |
| 00006 | `personal_org` | автосоздание личной организации при регистрации. |
| 00007 | `invites` | invite-коды организаций. |
| 00008 | `activity_log` | агрегатная лента активности. |
| 00009 | `oauth_identities` | связки внешних провайдеров. |
| 00010 | `refresh_tokens` | rotation refresh-токенов. |
| 00011 | `device_tokens` | APNs/FCM токены. |
| 00012 | `categories_unique_per_org` | уникальность имени. |
| 00013 | `variants_measure_unit` | `parent_item_id`, `measure_unit`, `volume_per_unit`. |
| 00014 | `holder_user_id` | назначение ответственного на вещь. |
| 00015 | `events` | события организации. |
| 00016 | `item_event` | первая версия связи (заменена в 00025). |
| 00017 | `indexes` | индексы для основных запросов и поиска. |
| 00018 | `image_url_text` | расширение поля под CDN-URL. |
| 00019 | `archive_reason_enum` | enum для причин архива. |
| 00020 | `optimistic_lock` | поддержка `updated_at`. |
| 00021 | `soft_delete` | колонки `deleted_at` для soft-delete. |
| 00022 | `expiration_notifications` | `expiration_notifications`, `user_notification_preferences`, `expiration_snoozes`. |
| 00023 | `item_comments` | `item_comments`, `comment_reactions`, SQL-функция парсинга mentions. |
| 00024 | `item_reservations` | `item_reservations(status, expires_at, ...)`. |
| 00025 | `reservations.event_id` | замена order/delivery/production reasons на `event_id` (FK на `events`). |

Подробности фич: см. [`Docs/Smart-Expiration-Notifications.md`](Docs/Smart-Expiration-Notifications.md), [`Docs/Item-Comments-System.md`](Docs/Item-Comments-System.md), [`Docs/Item-Reservation-System.md`](Docs/Item-Reservation-System.md), [`Docs/Soft-Delete-Implementation.md`](Docs/Soft-Delete-Implementation.md).

---

## 10. Безопасность

- **JWT HS256** ([`internal/infra/jwt`](backend/internal/infra/jwt)). `JWT_SECRET` обязателен; refresh-токен — отдельный с длинным TTL.
- **Refresh rotation**: каждый успешный `/auth/refresh` инвалидирует старый refresh, выпускает новый. Использование старого → отзыв всей цепочки.
- **OAuth (Telegram/Google/Apple)**: Telegram — HMAC-проверка `hash`; Google/Apple — JWKS-валидация `id_token`/`identity_token` (audience, issuer, signature, expiry). См. [`Docs/TelegramLoginSetup.md`](Docs/TelegramLoginSetup.md).
- **Rate limiting** ([`internal/infra/ratelimit/limiter.go`](backend/internal/infra/ratelimit/limiter.go:1)): токен-бакет на IP для `/auth/*` и на user для остального. Лимиты в env.
- **CORS** ([`Docs/CORS-Configuration.md`](Docs/CORS-Configuration.md)): whitelist через `CORS_ALLOWED_ORIGINS`.
- **Security headers**: HSTS, CSP-friendly, `X-Frame-Options: DENY`.
- **File upload security** ([`Docs/File-Upload-Security.md`](Docs/File-Upload-Security.md)): MIME-sniffing, лимит размера, реcompression через `internal/infra/imagecodec`.
- **CDN/S3** ([`Docs/CDN-S3-Integration.md`](Docs/CDN-S3-Integration.md)): абстракция `BlobStorage` (локальный fs / S3-совместимый).

---

## 11. Real-time / Push / Offline

### 11.1 WebSocket
- Backend: [`internal/adapter/websocket/hub.go`](backend/internal/adapter/websocket/hub.go:1) — central hub, broadcast на участников организации; [`broadcaster.go`](backend/internal/adapter/websocket/broadcaster.go:1) — публикация событий из usecase.
- iOS: [`WebSocketService.swift`](ios/cstatiWarehouse/Services/WebSocket/WebSocketService.swift:1) — `URLSessionWebSocketTask`, авторекоонект, фильтрация по `organization_id`. Обновляет presenter-ы через `itemChangedExternally`.
- См. [`backend/docs/WebSocket-Real-Time-Updates.md`](backend/docs/WebSocket-Real-Time-Updates.md).

### 11.2 Push (APNs)
- Регистрация токена: [`AppDelegate.swift`](ios/cstatiWarehouse/App/AppDelegate.swift:1) → `RemotePushRegistration` → `POST /devices`.
- Backend отправляет push: при mentions, при сработавших уровнях expiration. См. [`Docs/Push-Notifications-Enhancement.md`](Docs/Push-Notifications-Enhancement.md).

### 11.3 Local Notifications
- [`SmartExpirationScheduler.swift`](ios/cstatiWarehouse/Services/Notifications/SmartExpirationScheduler.swift:1) — локальные `UNTimeIntervalNotificationTrigger` как fallback (если APNs недоступен / push выключен).
- [`ExpirationNotificationActions.swift`](ios/cstatiWarehouse/Services/Notifications/ExpirationNotificationActions.swift:1) — actionable-уведомления: «Использовано», «+1 час», «+1 день», «Открыть».

### 11.4 Offline queue
- [`OfflineMutationQueue.swift`](ios/cstatiWarehouse/Services/Offline/OfflineMutationQueue.swift:1) — очередь мутаций при отсутствии сети (создание/архив/обновление). Воспроизводится при восстановлении.
- Кеш данных: [`SwiftDataOfflineCacheStore.swift`](ios/cstatiWarehouse/Persistence/SwiftDataOfflineCacheStore.swift:1) (SwiftData), ключи в [`OfflineCacheKeys.swift`](ios/cstatiWarehouse/Persistence/OfflineCacheKeys.swift:1).
- См. [`ios/cstatiWarehouse/Docs/CacheInvalidationStrategy.md`](ios/cstatiWarehouse/Docs/CacheInvalidationStrategy.md), [`BackgroundSyncStrategy.md`](ios/cstatiWarehouse/Docs/BackgroundSyncStrategy.md).

---

## 12. Smart Expiration — глубоко

Документ: [`Docs/Smart-Expiration-Notifications.md`](Docs/Smart-Expiration-Notifications.md).

- Backend cron: [`internal/infra/scheduler/expiration_scheduler.go`](backend/internal/infra/scheduler/expiration_scheduler.go:1), запускается из [`cmd/server/main.go`](backend/cmd/server/main.go:1) с интервалом из env.
- Алгоритм: для каждого активного item с `expiration_date` определяется максимальный сработавший уровень; для каждого участника организации (с учётом role и preferences) проверяется не было ли уже отправлено через `expiration_notifications`; quiet-hours окно отсекает пуш.
- Snooze: запись в `expiration_snoozes(item_id, user_id, snoozed_until)` блокирует уведомления до момента.
- iOS UI: [`NotificationPreferencesView.swift`](ios/cstatiWarehouse/Scenes/NotificationPreferences/NotificationPreferencesView.swift:1) с тремя toggle, picker'ом quiet hours и timezone, индикатором сохранения.

---

## 13. Comments — глубоко

Документ: [`Docs/Item-Comments-System.md`](Docs/Item-Comments-System.md).

- Тред: одиночная вложенность (root + replies через `parent_comment_id`).
- Mentions: парсинг через SQL-функцию (см. миграцию `00023`); при сохранении сервер проверяет, что упомянутые — участники организации.
- Реакции: уникальный constraint `(comment_id, user_id, type)`; iOS делает оптимистичные обновления и откатывает на ошибку ([`CommentsPresenter.swift`](ios/cstatiWarehouse/Scenes/Comments/CommentsPresenter.swift:215)).
- UI:
  - [`CommentsView.swift`](ios/cstatiWarehouse/Scenes/Comments/CommentsView.swift:1): композер внизу, контекстное меню (edit/delete/reply), reactions row с emoji-чипами.
  - empty/failed state, скелетоны, сборка реплик в `replies(for:)`.

---

## 14. Reservations — глубоко

Документ: [`Docs/Item-Reservation-System.md`](Docs/Item-Reservation-System.md).

- Доступность: `availability = item.quantity - sum(active.quantity)` через [`ReservationRepo.GetActiveTotalReservedForItem`](backend/internal/adapter/repo/reservation_repo.go:179).
- Создание: `event_id` опционален; если нет — резерв «без события». UI [`CreateReservationSheet`](ios/cstatiWarehouse/Scenes/Reservations/ReservationsView.swift:381) делает чип-flow совпадающий с `ItemEditView` категориями.
- Fulfill: атомарная транзакция в БД (резерв + `items.quantity -= reservation.quantity`).
- Cancel: с обязательным reason (UI: [`CancelReservationSheet`](ios/cstatiWarehouse/Scenes/Reservations/ReservationsView.swift:630)).
- TTL: фоновая задача переводит просроченные active в `expired`.
- iOS экран [`ReservationsView.swift`](ios/cstatiWarehouse/Scenes/Reservations/ReservationsView.swift:1): метрики (total/active/fulfilled), фильтр-чипы (`Все/Активные/Выполнены/Отменены/Просрочены`), карточки с действиями `Выполнить`/`Отменить`.

---

## 15. Overview Dashboard

Документ: [`Docs/Analytics-Dashboard.md`](Docs/Analytics-Dashboard.md).

- Backend: [`analytics.go`](backend/internal/usecase/analytics.go:1) — `GetDashboard(orgID)` → метрики + кеш в памяти (~60s).
- iOS: [`OverviewAssembly.swift`](ios/cstatiWarehouse/Scenes/Overview/OverviewAssembly.swift:1) + presenter/view. Карточки KPI, top-categories, shelf-risk bands ([`ShelfRiskBandTests.swift`](ios/cstatiWarehouseTests/Overview/ShelfRiskBandTests.swift:1)).

---

## 16. Route Planning

- Сцена: [`RoutePlanningView.swift`](ios/cstatiWarehouse/Scenes/RoutePlanning/RoutePlanningView.swift:1) + [`RoutePlanningInteractor.swift`](ios/cstatiWarehouse/Scenes/RoutePlanning/RoutePlanningInteractor.swift:1).
- Шаги:
  1. Выбор события (опционально) → подтягиваются связанные active-резервы и расставляют количества по item.
  2. Заполнение start/destination адресов (geocoding с debounce, inline preview).
  3. Список item'ов (root) с steppers для выбора количества.
  4. Сборка маршрута: [`MultiLegDrivingRouteAssembler.swift`](ios/cstatiWarehouse/Services/RoutePlanning/MultiLegDrivingRouteAssembler.swift:1) + `MKRoute`.
  5. Карта с пинами, карточки stop'ов, deeplink в Яндекс.Карты ([`YandexMapsRouteURLBuilder.swift`](ios/cstatiWarehouse/Services/RoutePlanning/YandexMapsRouteURLBuilder.swift:1)).
- Сортировка точек: [`PickupRouteOrdering.swift`](ios/cstatiWarehouse/Services/RoutePlanning/PickupRouteOrdering.swift:1) (TSP-greedy по distance matrix).

---

## 17. Локализация

- iOS: `Localizable.strings` (en/ru) + типобезопасный код-ген [`L10n.swift`](ios/cstatiWarehouse/Resources/Localization/L10n.swift:1). См. [`ios/cstatiWarehouse/Resources/Localization/README.md`](ios/cstatiWarehouse/Resources/Localization/README.md).
- Backend: [`internal/infra/i18n`](backend/internal/infra/i18n) — переводы шаблонов сообщений активности, пушей, ошибок.
- См. [`Docs/Internationalization-i18n.md`](Docs/Internationalization-i18n.md).

---

## 18. Дизайн-слой / UI-компоненты iOS

[`ios/cstatiWarehouse/CoreUI/`](ios/cstatiWarehouse/CoreUI):
- [`DesignSystem.swift`](ios/cstatiWarehouse/CoreUI/DesignSystem.swift:1) — токены: цвета, отступы, типографика, радиусы.
- [`AppGlass.swift`](ios/cstatiWarehouse/CoreUI/AppGlass.swift:1) — стеклянные подложки (`ultraThinMaterial`).
- [`GlassChip.swift`](ios/cstatiWarehouse/CoreUI/GlassChip.swift:1), [`GlassPillButton.swift`](ios/cstatiWarehouse/CoreUI/GlassPillButton.swift:1), [`GlassTextField.swift`](ios/cstatiWarehouse/CoreUI/GlassTextField.swift:1), [`GlassConfirmationSheet.swift`](ios/cstatiWarehouse/CoreUI/GlassConfirmationSheet.swift:1).
- [`FlowLayout.swift`](ios/cstatiWarehouse/CoreUI/FlowLayout.swift:1) — wrapping flow для чипов.
- [`DrumDatePicker.swift`](ios/cstatiWarehouse/CoreUI/DrumDatePicker.swift:1) — кастомный «барабанный» picker.
- [`ShimmerModifier.swift`](ios/cstatiWarehouse/CoreUI/ShimmerModifier.swift:1) — скелетоны.
- [`PassiveNetworkBanner.swift`](ios/cstatiWarehouse/CoreUI/PassiveNetworkBanner.swift:1) — статус сети.
- [`AnimatedGradientBackground.swift`](ios/cstatiWarehouse/CoreUI/GradientBackground/AnimatedGradientBackground.swift:1) — анимированный фон auth.
- [`ImagePicker/`](ios/cstatiWarehouse/CoreUI/ImagePicker) — `PhotoSourceSheet`, `RemoteImageView`, `RemoteImageCache`.
- [`AddressPreviewSheet.swift`](ios/cstatiWarehouse/CoreUI/AddressPreviewSheet.swift:1) и [`AddressGeocodeInlinePreview.swift`](ios/cstatiWarehouse/CoreUI/AddressGeocodeInlinePreview.swift:1) — UX для адресов.
- [`SheetHeader.swift`](ios/cstatiWarehouse/CoreUI/Sheets/SheetHeader.swift:1) — единый header модалок.
- [`TelegramLoginButton.swift`](ios/cstatiWarehouse/CoreUI/TelegramLoginButton.swift:1).
- [`WarehouseItemCard.swift`](ios/cstatiWarehouse/CoreUI/WarehouseItemCard.swift:1) — карточка вещи на главной.

Хаптика: см. [`Docs/Haptic-Feedback-Guidelines.md`](Docs/Haptic-Feedback-Guidelines.md).

---

## 19. Quick start

```bash
# Backend
cd backend
cp .env.example .env
# заполнить JWT_SECRET и DB_DSN
make migrate-up
make run        # http://localhost:8080
```

```bash
# iOS
open ios/cstatiWarehouse.xcodeproj
# выбрать схему cstatiWarehouse, target — симулятор iOS 17+
# выставить APIClient.baseURL под локальный backend (по умолчанию http://localhost:8080)
```

См. также [`backend/README.md`](backend/README.md) §4 и [`ios/README.md`](ios/README.md) §7.

---

## 20. Тестирование

### 20.1 Backend
- `go test ./...` запускает unit и integration тесты ([`backend/docs/Integration-Testing-Guide.md`](backend/docs/Integration-Testing-Guide.md)).
- Тестовый Postgres поднимается через `docker-compose` или testcontainers.
- Контракты usecase — [`internal/usecase/*_test.go`](backend/internal/usecase) с фейковыми портами ([`fakes_test.go`](backend/internal/usecase/fakes_test.go:1)).

### 20.2 iOS
- Unit: `cstatiWarehouseTests/` — Swift Testing framework (`@Suite`/`@Test`). Покрытие: presenters, interactors, services, persistence, utilities.
- UI: `cstatiWarehouseUITests/` — `XCUIApplication`, флаги через [`UITestArguments.swift`](ios/cstatiWarehouseUITests/UITestArguments.swift:1).
- Подмены сервисов: [`MockAuthService.swift`](ios/cstatiWarehouseTests/TestDoubles/MockAuthService.swift:1), [`MockWarehouseService.swift`](ios/cstatiWarehouseTests/TestDoubles/MockWarehouseService.swift:1) и др.
- Запуск: `xcodebuild test -scheme cstatiWarehouse -destination 'platform=iOS Simulator,name=iPhone 15'`.

---

## 21. Конфигурация (env)

См. [`backend/.env.example`](backend/.env.example) и [`backend/README.md`](backend/README.md) §5. Ключевые переменные:
- `APP_ENV`, `LISTEN_ADDR`, `BASE_URL`.
- `DB_DSN` (Postgres).
- `JWT_SECRET`, `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`.
- `CORS_ALLOWED_ORIGINS`.
- `RATE_LIMIT_AUTH_*`, `RATE_LIMIT_USER_*`.
- `EXPIRATION_SCAN_INTERVAL`, `RESERVATION_EXPIRY_SCAN_INTERVAL`.
- `S3_BUCKET`/`S3_ENDPOINT`/`S3_REGION`/`S3_ACCESS_KEY`/`S3_SECRET_KEY` (опционально).
- `APNS_*` (для push).
- `TG_BOT_TOKEN`, `GOOGLE_OAUTH_CLIENT_ID`, `APPLE_*` (OAuth).

---

## 22. Указатель документации

### Корневой `Docs/`
- [`ADR/ADR-0001-clean-architecture.md`](Docs/ADR/ADR-0001-clean-architecture.md)
- [`Analytics-Dashboard.md`](Docs/Analytics-Dashboard.md)
- [`CDN-S3-Integration.md`](Docs/CDN-S3-Integration.md)
- [`CORS-Configuration.md`](Docs/CORS-Configuration.md)
- [`Database-Query-Optimization.md`](Docs/Database-Query-Optimization.md)
- [`Deployment-Guide.md`](Docs/Deployment-Guide.md)
- [`File-Upload-Security.md`](Docs/File-Upload-Security.md)
- [`Haptic-Feedback-Guidelines.md`](Docs/Haptic-Feedback-Guidelines.md)
- [`Image-Compression-Strategy.md`](Docs/Image-Compression-Strategy.md)
- [`Internationalization-i18n.md`](Docs/Internationalization-i18n.md)
- [`iOS-Lazy-Image-Loading.md`](Docs/iOS-Lazy-Image-Loading.md)
- [`Item-Comments-System.md`](Docs/Item-Comments-System.md)
- [`Item-Reservation-System.md`](Docs/Item-Reservation-System.md)
- [`OpenAPI-Swagger-Documentation.md`](Docs/OpenAPI-Swagger-Documentation.md)
- [`Push-Notifications-Enhancement.md`](Docs/Push-Notifications-Enhancement.md)
- [`Rate-Limiting.md`](Docs/Rate-Limiting.md)
- [`Smart-Expiration-Notifications.md`](Docs/Smart-Expiration-Notifications.md)
- [`Soft-Delete-Implementation.md`](Docs/Soft-Delete-Implementation.md)
- [`TelegramLoginSetup.md`](Docs/TelegramLoginSetup.md)

### `backend/docs/`
- [`Context-UserID-Migration.md`](backend/docs/Context-UserID-Migration.md)
- [`CQRS-Repository-Split.md`](backend/docs/CQRS-Repository-Split.md)
- [`Feature-Implementation-Roadmap.md`](backend/docs/Feature-Implementation-Roadmap.md)
- [`Integration-Testing-Guide.md`](backend/docs/Integration-Testing-Guide.md)
- [`Observability.md`](backend/docs/Observability.md)
- [`WebSocket-Real-Time-Updates.md`](backend/docs/WebSocket-Real-Time-Updates.md)

### `ios/cstatiWarehouse/Docs/`
- [`BackgroundSyncStrategy.md`](ios/cstatiWarehouse/Docs/BackgroundSyncStrategy.md)
- [`CacheInvalidationStrategy.md`](ios/cstatiWarehouse/Docs/CacheInvalidationStrategy.md)
- [`ErrorHandlingStrategy.md`](ios/cstatiWarehouse/Docs/ErrorHandlingStrategy.md)

---

## 23. Частые задачи → куда смотреть

| Задача | Файлы |
| --- | --- |
| Добавить новый эндпоинт | `backend/internal/usecase/<feature>.go` → `adapter/repo/...` → `adapter/httpapi/<feature>_handler.go` → регистрация в [`router.go`](backend/internal/adapter/httpapi/router.go:1) → клиент `ios/.../Services/<Feature>/Api*.swift` |
| Новое поле у вещи | миграция в `backend/migrations/` → `domain/item.go` → `repo/item_repo.go` → DTO в handler → `Entity/Item.swift` → presenter/view |
| Новый экран | `ios/cstatiWarehouse/Scenes/<Name>/` (Assembly + Interactor + Presenter + Router + View) → роутинг через [`AppCoordinator`](ios/cstatiWarehouse/Coordinator/AppCoordinator.swift:1) или [`MainTabCoordinator`](ios/cstatiWarehouse/Coordinator/MainTabCoordinator.swift:1) |
| Push-уведомление | usecase публикует через port `PushNotifier` → `infra/push` → APNs; на iOS — ловит [`AppDelegate`](ios/cstatiWarehouse/App/AppDelegate.swift:1) / `UNUserNotificationCenter` |
| Локализация | добавить ключ в обе `Localizable.strings`, перегенерировать [`L10n.swift`](ios/cstatiWarehouse/Resources/Localization/L10n.swift:1) |
| Изменить роль/доступ | проверки в usecase (порт `MemberReadPort.FindRole`) → возврат `domain.ForbiddenError` → клиент маппит через `APIError` |

---

## 24. Стандарты кода

- **Backend (Go):** `gofmt -s`, `go vet`, ошибки оборачиваем `fmt.Errorf("%w", err)`, `context.Context` первым параметром, никаких `panic` в HTTP-слое (recover-middleware ловит). Доменные ошибки — типизированные ([`internal/domain/errors.go`](backend/internal/domain/errors.go:1)). Logging — структурированный, минимум персональных данных.
- **iOS (Swift):** SwiftUI + `@Observable`, без `Combine` в новых сценах. VIPER-разделение (Assembly/Interactor/Presenter/Router/View). Без force-unwrap в production-коде; force-try только в тестах. Все «main-actor isolated» структуры тестов помечены `@MainActor` ([`RoutePlanningInteractorTests.swift`](ios/cstatiWarehouseTests/Scenes/RoutePlanning/RoutePlanningInteractorTests.swift:13)).
- **DTO ↔ Entity:** DTO живут в Api*-сервисах, Entity — в `Entity/`. Маппинг — в `toDomain()`. Ключи snake_case через `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` (исключения через явные `CodingKeys`).
- **Тесты:** один тест — одна проверка; имя теста описывает поведение.
- **Документация:** новые фичи — отдельный `.md` в `Docs/`; ссылка из этого README в §22.
