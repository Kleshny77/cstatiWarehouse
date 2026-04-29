# Context для User ID в UseCases (BREAKING CHANGE)

## Обзор

Миграция на передачу User ID через context.Context вместо явных параметров в каждом методе usecase.

## Мотивация

### Текущая проблема
```go
func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    // UserID передаётся в структуре Input
    // Дублирование во всех методах
}
```

### Решение
```go
func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    userID := auth.UserIDFromContext(ctx)
    // UserID извлекается из контекста
}
```

## Преимущества

1. **Единообразие**: User ID всегда доступен через контекст
2. **Меньше параметров**: Упрощение сигнатур методов
3. **Middleware integration**: Естественная интеграция с HTTP middleware
4. **Трейсинг**: User ID автоматически в логах и трейсах

## Реализация

### Шаг 1: Создать пакет auth/context

```go
// internal/infra/auth/context.go
package auth

import (
    "context"
    "errors"
    
    "github.com/google/uuid"
)

type contextKey string

const userIDKey contextKey = "user_id"

var ErrNoUserID = errors.New("no user ID in context")

// WithUserID добавляет user ID в контекст
func WithUserID(ctx context.Context, userID uuid.UUID) context.Context {
    return context.WithValue(ctx, userIDKey, userID)
}

// UserIDFromContext извлекает user ID из контекста
func UserIDFromContext(ctx context.Context) (uuid.UUID, error) {
    userID, ok := ctx.Value(userIDKey).(uuid.UUID)
    if !ok {
        return uuid.UUID{}, ErrNoUserID
    }
    return userID, nil
}

// MustUserIDFromContext извлекает user ID или паникует
func MustUserIDFromContext(ctx context.Context) uuid.UUID {
    userID, err := UserIDFromContext(ctx)
    if err != nil {
        panic(err)
    }
    return userID
}
```

### Шаг 2: Обновить middleware

```go
// adapter/httpapi/middleware.go
func authMiddleware(verifier jwt.Verifier) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := extractToken(r)
            if token == "" {
                writeError(w, r, domain.ErrUnauthorized)
                return
            }
            
            claims, err := verifier.Verify(token)
            if err != nil {
                writeError(w, r, domain.ErrUnauthorized)
                return
            }
            
            // Добавляем user ID в контекст
            ctx := auth.WithUserID(r.Context(), claims.UserID)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### Шаг 3: Обновить UseCases

#### До
```go
type CreateItemInput struct {
    UserID         uuid.UUID
    OrganizationID uuid.UUID
    Name           string
    // ...
}

func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    // Проверка прав доступа
    if err := uc.orgs.CheckMembership(ctx, in.OrganizationID, in.UserID); err != nil {
        return nil, domain.ErrForbidden
    }
    
    // Создание позиции
    item := &domain.Item{
        ID:             uuid.New(),
        Name:           in.Name,
        OrganizationID: in.OrganizationID,
        CreatedByID:    in.UserID,
        // ...
    }
    // ...
}
```

#### После
```go
type CreateItemInput struct {
    // UserID удалён - берётся из контекста
    OrganizationID uuid.UUID
    Name           string
    // ...
}

func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    // Извлекаем user ID из контекста
    userID, err := auth.UserIDFromContext(ctx)
    if err != nil {
        return nil, err
    }
    
    // Проверка прав доступа
    if err := uc.orgs.CheckMembership(ctx, in.OrganizationID, userID); err != nil {
        return nil, domain.ErrForbidden
    }
    
    // Создание позиции
    item := &domain.Item{
        ID:             uuid.New(),
        Name:           in.Name,
        OrganizationID: in.OrganizationID,
        CreatedByID:    userID,
        // ...
    }
    // ...
}
```

### Шаг 4: Обновить Handlers

#### До
```go
func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
    userID, ok := currentUserID(r)
    if !ok {
        writeError(w, r, domain.ErrUnauthorized)
        return
    }
    
    var req createItemRequest
    if err := decodeJSON(r, &req); err != nil {
        writeError(w, r, err)
        return
    }
    
    item, err := h.warehouse.Create(r.Context(), usecase.CreateItemInput{
        UserID:         userID,
        OrganizationID: req.OrganizationID,
        Name:           req.Name,
        // ...
    })
    // ...
}
```

#### После
```go
func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
    // User ID уже в контексте благодаря middleware
    
    var req createItemRequest
    if err := decodeJSON(r, &req); err != nil {
        writeError(w, r, err)
        return
    }
    
    item, err := h.warehouse.Create(r.Context(), usecase.CreateItemInput{
        // UserID удалён
        OrganizationID: req.OrganizationID,
        Name:           req.Name,
        // ...
    })
    // ...
}
```

## План миграции

### Фаза 1: Подготовка (без breaking changes)
1. Создать пакет `internal/infra/auth`
2. Обновить middleware для добавления user ID в контекст
3. Добавить helper методы для извлечения user ID

### Фаза 2: Миграция UseCases (BREAKING)
1. Обновить все Input структуры - удалить UserID поля
2. Обновить все методы UseCases - извлекать user ID из контекста
3. Обновить все тесты

### Фаза 3: Миграция Handlers
1. Удалить `currentUserID` helper
2. Упростить handlers - убрать явную передачу UserID

### Фаза 4: Cleanup
1. Удалить старый код
2. Обновить документацию

## Тестирование

```go
func TestWarehouseUseCase_Create(t *testing.T) {
    // Setup
    uc := setupUseCase(t)
    
    userID := uuid.New()
    orgID := uuid.New()
    
    // Добавляем user ID в контекст
    ctx := auth.WithUserID(context.Background(), userID)
    
    // Test
    item, err := uc.Create(ctx, usecase.CreateItemInput{
        OrganizationID: orgID,
        Name:           "Test Item",
        // UserID не передаётся
    })
    
    if err != nil {
        t.Fatal(err)
    }
    
    if item.CreatedByID != userID {
        t.Errorf("expected created_by_id %s, got %s", userID, item.CreatedByID)
    }
}
```

## Обратная совместимость

Нет - это BREAKING CHANGE. Требует обновления всех вызовов UseCases.

## Альтернативы

1. **Оставить как есть** - дублирование, но явно
2. **Гибридный подход** - поддерживать оба способа (сложность)
3. **Только для новых методов** - несогласованность
