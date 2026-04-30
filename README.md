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
2. **Иерархия товаров** — у одного «логического» товара могут быть **варианты** (фасовки): «Сок» → «1 л», «0.5 л». При этом по-прежнему один экран «склад» и одна агрегация литров для отчётности.
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
| **Variant** | Подпозиция — фасовка/размер существующего Item'а (например «1 л» внутри «Сок»). У группы (родителя с детьми) количество хранится на вариантах. |
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
  - **Toggle «Несколько фасовок»** (только в режиме create) — превращает создаваемый Item в **родителя**, на который будут вешаться варианты.
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
1. `securityHeadersMiddleware`,
2. `recoverMiddleware` (паника → 500, не падает процесс),
3. `loggingMiddleware` (request-id, method, path, status, latency),
4. `corsM
