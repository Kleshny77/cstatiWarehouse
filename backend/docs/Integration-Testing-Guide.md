# Integration Testing Guide

## Обзор

Руководство по написанию HTTP интеграционных тестов и тестов миграций.

## HTTP Integration Tests

### Структура

```go
// internal/adapter/httpapi/integration_test.go
package httpapi_test

import (
    "context"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/httpapi"
    "github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
    "github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

func TestWarehouseIntegration(t *testing.T) {
    // Setup: создать тестовую БД
    pool := setupTestDB(t)
    defer pool.Close()
    
    // Setup: создать зависимости
    itemRepo := repo.NewItemRepo(pool)
    orgRepo := repo.NewOrganizationRepo(pool)
    activityLogger := &fakeActivityLogger{}
    
    warehouseUC := usecase.NewWarehouseUseCase(
        itemRepo,
        orgRepo,
        activityLogger,
        clock.Fixed(time.Now()),
    )
    
    // Setup: создать router
    handler := httpapi.NewWarehouseHandler(warehouseUC)
    router := httpapi.NewRouter(httpapi.RouterDeps{
        Warehouse: handler,
        // ...
    })
    
    // Test: создать позицию
    t.Run("create item", func(t *testing.T) {
        body := `{
            "name": "Test Item",
            "category_name": "Test",
            "quantity": 10,
            "location_address": "Test Address"
        }`
        
        req := httptest.NewRequest(http.MethodPost, "/warehouse/items", strings.NewReader(body))
        req.Header.Set("Content-Type", "application/json")
        req.Header.Set("Authorization", "Bearer "+testToken)
        
        rec := httptest.NewRecorder()
        router.ServeHTTP(rec, req)
        
        if rec.Code != http.StatusCreated {
            t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
        }
        
        var resp struct {
            Item struct {
                ID   string `json:"id"`
                Name string `json:"name"`
            } `json:"item"`
        }
        
        if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
            t.Fatal(err)
        }
        
        if resp.Item.Name != "Test Item" {
            t.Errorf("expected name 'Test Item', got %q", resp.Item.Name)
        }
    })
}

func setupTestDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    
    // Создать временную БД для теста
    dbName := "test_" + strings.ReplaceAll(uuid.New().String(), "-", "")
    
    // Подключиться к postgres для создания БД
    adminDSN := "postgres://postgres:postgres@localhost:5432/postgres"
    adminPool, err := pgxpool.New(context.Background(), adminDSN)
    if err != nil {
        t.Fatal(err)
    }
    defer adminPool.Close()
    
    // Создать тестовую БД
    _, err = adminPool.Exec(context.Background(), "CREATE DATABASE "+dbName)
    if err != nil {
        t.Fatal(err)
    }
    
    // Подключиться к тестовой БД
    testDSN := fmt.Sprintf("postgres://postgres:postgres@localhost:5432/%s", dbName)
    pool, err := pgxpool.New(context.Background(), testDSN)
    if err != nil {
        t.Fatal(err)
    }
    
    // Применить миграции
    if err := runMigrations(pool); err != nil {
        t.Fatal(err)
    }
    
    // Cleanup: удалить БД после теста
    t.Cleanup(func() {
        pool.Close()
        _, _ = adminPool.Exec(context.Background(), "DROP DATABASE "+dbName)
    })
    
    return pool
}
```

### Тестовые сценарии

1. **CRUD операции**
   - Создание позиции
   - Чтение позиции
   - Обновление позиции
   - Удаление позиции

2. **Авторизация**
   - Доступ без токена → 401
   - Доступ с невалидным токеном → 401
   - Доступ к чужой организации → 403

3. **Валидация**
   - Невалидный JSON → 400
   - Отсутствующие поля → 422
   - Некорректные значения → 422

4. **Конкурентность**
   - Optimistic locking (expectedUpdatedAt)
   - Параллельные обновления

## Migration Tests

### Структура

```go
// migrations/migrations_test.go
package migrations_test

import (
    "context"
    "testing"
    
    "github.com/pressly/goose/v3"
)

func TestMigrationsUpDown(t *testing.T) {
    pool := setupTestDB(t)
    defer pool.Close()
    
    // Получить список всех миграций
    migrations, err := goose.CollectMigrations(".", 0, goose.MaxVersion)
    if err != nil {
        t.Fatal(err)
    }
    
    for _, migration := range migrations {
        t.Run(migration.Source, func(t *testing.T) {
            // Применить миграцию
            if err := goose.UpTo(pool, ".", migration.Version); err != nil {
                t.Fatalf("up failed: %v", err)
            }
            
            // Откатить миграцию
            if err := goose.Down(pool, "."); err != nil {
                t.Fatalf("down failed: %v", err)
            }
            
            // Применить снова для следующего теста
            if err := goose.UpTo(pool, ".", migration.Version); err != nil {
                t.Fatalf("re-up failed: %v", err)
            }
        })
    }
}

func TestMigrationIdempotency(t *testing.T) {
    pool := setupTestDB(t)
    defer pool.Close()
    
    // Применить все миграции
    if err := goose.Up(pool, "."); err != nil {
        t.Fatal(err)
    }
    
    // Применить ещё раз - должно быть безопасно
    if err := goose.Up(pool, "."); err != nil {
        t.Fatal(err)
    }
}

func TestMigrationDataIntegrity(t *testing.T) {
    pool := setupTestDB(t)
    defer pool.Close()
    
    // Применить миграции до определённой версии
    if err := goose.UpTo(pool, ".", 5); err != nil {
        t.Fatal(err)
    }
    
    // Вставить тестовые данные
    _, err := pool.Exec(context.Background(), `
        INSERT INTO items (id, name, quantity, organization_id, created_by_id)
        VALUES ($1, $2, $3, $4, $5)
    `, uuid.New(), "Test", 10, testOrgID, testUserID)
    if err != nil {
        t.Fatal(err)
    }
    
    // Применить следующую миграцию
    if err := goose.UpTo(pool, ".", 6); err != nil {
        t.Fatal(err)
    }
    
    // Проверить что данные сохранились
    var count int
    err = pool.QueryRow(context.Background(), "SELECT COUNT(*) FROM items").Scan(&count)
    if err != nil {
        t.Fatal(err)
    }
    
    if count != 1 {
        t.Errorf("expected 1 item, got %d", count)
    }
}
```

### Запуск тестов

```bash
# Интеграционные тесты
go test -v ./internal/adapter/httpapi -tags=integration

# Тесты миграций
go test -v ./migrations

# Все тесты
go test -v ./...
```

### CI/CD

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-go@v4
        with:
          go-version: '1.22'
      
      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out ./...
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/postgres
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```
