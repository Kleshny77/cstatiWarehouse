# CQRS Repository Split

## Обзор

Разделение ItemRepository на Reader и Writer интерфейсы для улучшения разделения ответственности и оптимизации запросов.

## Архитектура

### ItemReader (Query Side)

```go
// usecase/ports.go
type ItemReader interface {
    // Queries - только чтение
    GetByID(ctx context.Context, id uuid.UUID) (*domain.Item, error)
    ListByOrganization(ctx context.Context, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error)
    HasChildRows(ctx context.Context, parentID uuid.UUID) (bool, error)
    CountInStockChildrenWithPositiveQuantity(ctx context.Context, parentID uuid.UUID) (int64, error)
    ListArchiveEvents(ctx context.Context, orgID uuid.UUID, limit, offset int) ([]domain.ArchiveEvent, error)
    ListCategoriesByOrganization(ctx context.Context, orgID uuid.UUID) ([]string, error)
}
```

### ItemWriter (Command Side)

```go
// usecase/ports.go
type ItemWriter interface {
    // Commands - изменение данных
    Create(ctx context.Context, item *domain.Item) error
    Update(ctx context.Context, item *domain.Item, expectedUpdatedAt *time.Time) error
    Delete(ctx context.Context, id uuid.UUID) error
    CreateArchiveEvent(ctx context.Context, event *domain.ArchiveEvent) error
}
```

### Композиция в UseCase

```go
type WarehouseUseCase struct {
    reader   ItemReader
    writer   ItemWriter
    orgs     OrganizationRepository
    activity ActivityLogger
    clock    clock.Clock
}

func NewWarehouseUseCase(
    reader ItemReader,
    writer ItemWriter,
    orgs OrganizationRepository,
    activity ActivityLogger,
    clock clock.Clock,
) *WarehouseUseCase {
    return &WarehouseUseCase{
        reader:   reader,
        writer:   writer,
        orgs:     orgs,
        activity: activity,
        clock:    clock,
    }
}
```

## Преимущества

### 1. Разделение ответственности
- Reader: оптимизирован для чтения (индексы, денормализация)
- Writer: оптимизирован для записи (транзакции, валидация)

### 2. Масштабируемость
- Reader может использовать read replicas
- Writer работает с master БД

### 3. Тестируемость
- Легче мокировать отдельные интерфейсы
- Тесты более фокусированные

### 4. Будущее расширение
- Возможность использовать разные хранилища (CQRS с event sourcing)
- Кеширование на уровне Reader

## Реализация

### ItemReaderImpl

```go
// adapter/repo/item_reader.go
type ItemReaderImpl struct {
    pool *pgxpool.Pool
}

func NewItemReader(pool *pgxpool.Pool) *ItemReaderImpl {
    return &ItemReaderImpl{pool: pool}
}

func (r *ItemReaderImpl) GetByID(ctx context.Context, id uuid.UUID) (*domain.Item, error) {
    // Оптимизированный запрос для чтения
    query := `
        SELECT id, name, description, category_name, quantity, status, 
               organization_id, created_by_id, held_by_user_id,
               parent_item_id, variant_label, measure_unit, volume_per_unit,
               expiration_date, location_address, location_lat, location_lon,
               created_at, updated_at
        FROM items
        WHERE id = $1
    `
    // ...
}
```

### ItemWriterImpl

```go
// adapter/repo/item_writer.go
type ItemWriterImpl struct {
    pool *pgxpool.Pool
}

func NewItemWriter(pool *pgxpool.Pool) *ItemWriterImpl {
    return &ItemWriterImpl{pool: pool}
}

func (w *ItemWriterImpl) Create(ctx context.Context, item *domain.Item) error {
    // Транзакция для записи
    tx, err := w.pool.Begin(ctx)
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)
    
    // INSERT запрос
    // ...
    
    return tx.Commit(ctx)
}
```

## Миграция

### Шаг 1: Создать новые интерфейсы
Добавить ItemReader и ItemWriter в ports.go

### Шаг 2: Реализовать адаптеры
Создать item_reader.go и item_writer.go

### Шаг 3: Обновить UseCase
Изменить конструктор и методы для использования reader/writer

### Шаг 4: Обновить composition root
```go
// cmd/server/main.go
itemReader := repo.NewItemReader(pool)
itemWriter := repo.NewItemWriter(pool)

warehouseUC := usecase.NewWarehouseUseCase(
    itemReader,
    itemWriter,
    orgRepo,
    activityLogger,
    clock.System,
)
```

### Шаг 5: Обновить тесты
Использовать отдельные моки для reader и writer
