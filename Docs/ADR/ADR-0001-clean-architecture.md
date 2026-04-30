# ADR-0001: Clean Architecture с Ports & Adapters

## Статус
✅ Принято (2024-01-15)

## Контекст

При разработке backend для cstatiWarehouse нам нужна архитектура, которая обеспечивает:

### Требования
- **Тестируемость** - бизнес-логика должна легко тестироваться без внешних зависимостей
- **Независимость от фреймворков** - возможность менять HTTP роутер, ORM, БД без изменения бизнес-логики
- **Масштабируемость** - четкое разделение ответственности для роста команды
- **Поддерживаемость** - новые разработчики должны быстро понимать структуру

### Ограничения
- Команда из 2-3 разработчиков
- Монолитное приложение (не микросервисы)
- Go как основной язык
- Необходимость быстрого MVP

## Решение

Используем **Clean Architecture** с паттерном **Ports & Adapters** (Hexagonal Architecture).

### Структура проекта

```
backend/
├── cmd/
│   └── server/
│       └── main.go              # Composition root
├── internal/
│   ├── domain/                  # Бизнес-сущности и правила
│   │   ├── item.go
│   │   ├── organization.go
│   │   ├── user.go
│   │   └── errors.go
│   ├── usecase/                 # Use cases + Ports (интерфейсы)
│   │   ├── warehouse.go
│   │   ├── auth.go
│   │   ├── organizations.go
│   │   └── ports.go             # Интерфейсы репозиториев
│   ├── adapter/                 # Adapters (реализации портов)
│   │   ├── httpapi/             # HTTP handlers
│   │   ├── repo/                # PostgreSQL repositories
│   │   └── websocket/           # WebSocket handlers
│   └── infra/                   # Инфраструктурный код
│       ├── config/
│       ├── postgres/
│       └── jwt/
└── migrations/                  # Database migrations
```

### Слои и зависимости

```
┌─────────────────────────────────────────┐
│         HTTP / WebSocket / CLI          │  ← Adapters (входящие)
├─────────────────────────────────────────┤
│            Use Cases                    │  ← Бизнес-логика
├─────────────────────────────────────────┤
│         Domain Entities                 │  ← Бизнес-сущности
├─────────────────────────────────────────┤
│    Repositories / External Services     │  ← Adapters (исходящие)
└─────────────────────────────────────────┘
```

**Правило зависимостей**: Зависимости направлены внутрь (к domain).

### Ключевые принципы

1. **Domain Layer** - независим от всего:
   ```go
   // domain/item.go
   type Item struct {
       ID             uuid.UUID
       Name           string
       Quantity       int
       OrganizationID uuid.UUID
       // ... бизнес-поля
   }
   
   func (i *Item) IsExpired() bool {
       // Бизнес-логика без внешних зависимостей
   }
   ```

2. **Use Case Layer** - определяет интерфейсы (ports):
   ```go
   // usecase/ports.go
   type ItemRepository interface {
       Create(ctx context.Context, item *domain.Item) error
       GetByID(ctx context.Context, id uuid.UUID) (*domain.Item, error)
       // ...
   }
   
   // usecase/warehouse.go
   type WarehouseUseCase struct {
       repo ItemRepository  // Зависимость от интерфейса
   }
   ```

3. **Adapter Layer** - реализует интерфейсы:
   ```go
   // adapter/repo/item_repo.go
   type ItemRepo struct {
       db *pgxpool.Pool
   }
   
   func (r *ItemRepo) Create(ctx context.Context, item *domain.Item) error {
       // PostgreSQL-специфичная реализация
   }
   ```

4. **Composition Root** - собирает все вместе:
   ```go
   // cmd/server/main.go
   func run() error {
       db := postgres.Connect(cfg.Database)
       
       // Создаем адаптеры
       itemRepo := repo.NewItemRepo(db)
       
       // Создаем use cases
       warehouseUC := usecase.NewWarehouseUseCase(itemRepo)
       
       // Создаем HTTP handlers
       warehouseHandler := httpapi.NewWarehouseHandler(warehouseUC)
       
       // Запускаем сервер
       router := httpapi.NewRouter(warehouseHandler)
       http.ListenAndServe(":8080", router)
   }
   ```

### Тестирование

**Unit тесты** (use cases):
```go
func TestWarehouseUseCase_Create(t *testing.T) {
    // Используем fake repository (без БД)
    repo := &FakeItemRepo{}
    uc := usecase.NewWarehouseUseCase(repo)
    
    item, err := uc.Create(ctx, input)
    
    assert.NoError(t, err)
    assert.NotNil(t, item)
}
```

**Integration тесты** (repositories):
```go
func TestItemRepo_Create(t *testing.T) {
    // Используем реальную БД (testcontainers)
    db := setupTestDB(t)
    repo := repo.NewItemRepo(db)
    
    err := repo.Create(ctx, item)
    
    assert.NoError(t, err)
}
```

## Последствия

### Положительные

+ **Тестируемость**: Use cases тестируются с fake repositories без БД
+ **Независимость**: Можем менять БД (PostgreSQL → MongoDB) без изменения use cases
+ **Четкое разделение**: Каждый слой имеет свою ответственность
+ **Масштабируемость**: Легко добавлять новые use cases и адаптеры
+ **Понятность**: Новые разработчики быстро понимают структуру
+ **Переиспользование**: Use cases можно использовать из HTTP, CLI, gRPC

### Отрицательные

- **Boilerplate**: Больше файлов и интерфейсов
- **Сложность для простых CRUD**: Иногда избыточно для простых операций
- **Дисциплина**: Требует следования правилам от всей команды
- **Кривая обучения**: Новичкам нужно время на понимание

### Риски

- **Нарушение правил**: Разработчики могут обходить архитектуру
  - *Митигация*: Code review, линтеры, документация
- **Over-engineering**: Можем усложнить простые вещи
  - *Митигация*: Прагматичный подход, не все требует use case

## Альтернативы

### Альтернатива 1: MVC (Model-View-Controller)

**Описание**: Классический MVC с моделями, контроллерами и представлениями.

```
backend/
├── models/        # Модели БД
├── controllers/   # HTTP handlers
└── views/         # Templates (для API не нужны)
```

**Почему отклонено**:
- Смешивает бизнес-логику и HTTP concerns
- Сложно тестировать без HTTP
- Модели зависят от БД (ORM)
- Нет четкого разделения ответственности

### Альтернатива 2: Layered Architecture

**Описание**: Традиционная слоистая архитектура.

```
backend/
├── presentation/  # HTTP handlers
├── business/      # Бизнес-логика
├── data/          # Repositories
└── database/      # БД
```

**Почему отклонено**:
- Зависимости идут вниз (presentation → business → data → database)
- Бизнес-логика зависит от data layer
- Сложно менять БД без изменения business layer
- Менее гибко, чем Ports & Adapters

### Альтернатива 3: Flat Structure

**Описание**: Все файлы в одной директории.

```
backend/
├── item.go
├── item_handler.go
├── item_repo.go
├── user.go
├── user_handler.go
└── ...
```

**Почему отклонено**:
- Не масштабируется при росте проекта
- Нет четкого разделения concerns
- Сложно найти нужный файл
- Высокая связанность

### Альтернатива 4: Domain-Driven Design (DDD)

**Описание**: Полноценный DDD с aggregates, value objects, domain events.

```
backend/
├── domain/
│   ├── warehouse/
│   │   ├── aggregate/
│   │   ├── entity/
│   │   ├── value_object/
│   │   └── event/
│   └── organization/
└── ...
```

**Почему отклонено**:
- Слишком сложно для нашего размера проекта
- Требует глубокого понимания DDD от всей команды
- Избыточно для CRUD-операций
- Можем добавить DDD-элементы позже при необходимости

## Примеры использования

### Добавление нового use case

1. Создать интерфейс в `usecase/ports.go`:
   ```go
   type NotificationService interface {
       Send(ctx context.Context, userID uuid.UUID, message string) error
   }
   ```

2. Создать use case в `usecase/notifications.go`:
   ```go
   type NotificationsUseCase struct {
       service NotificationService
   }
   ```

3. Создать адаптер в `adapter/notification/`:
   ```go
   type APNsService struct {
       client *apns.Client
   }
   
   func (s *APNsService) Send(ctx context.Context, userID uuid.UUID, message string) error {
       // Реализация
   }
   ```

4. Собрать в `cmd/server/main.go`:
   ```go
   apnsService := notification.NewAPNsService(cfg.APNs)
   notificationsUC := usecase.NewNotificationsUseCase(apnsService)
   ```

### Смена БД

Если нужно мигрировать с PostgreSQL на MongoDB:

1. Создать новый адаптер `adapter/repo/mongo/item_repo.go`
2. Реализовать интерфейс `ItemRepository`
3. Изменить composition root:
   ```go
   // Было:
   itemRepo := repo.NewItemRepo(pgPool)
   
   // Стало:
   itemRepo := mongo.NewItemRepo(mongoClient)
   ```

Use cases остаются без изменений!

## Метрики успеха

Через 6 месяцев оценим:

- ✅ **Покрытие тестами**: > 80% для use cases
- ✅ **Время онбординга**: < 2 дней для нового разработчика
- ✅ **Количество нарушений**: < 5% pull requests нарушают архитектуру
- ✅ **Скорость разработки**: Новый use case за < 1 день

## Ссылки

- [Clean Architecture (Robert Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture (Alistair Cockburn)](https://alistair.cockburn.us/hexagonal-architecture/)
- [Go Clean Architecture Example](https://github.com/bxcodec/go-clean-arch)
- [Внутреннее обсуждение](https://github.com/cstati/warehouse/discussions/1)

## История изменений

- **2024-01-15**: Принято решение
- **2024-03-20**: Добавлен пример смены БД
- **2024-06-10**: Обновлены метрики успеха (все достигнуты)
