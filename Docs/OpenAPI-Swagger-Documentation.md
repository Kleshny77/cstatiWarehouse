# OpenAPI/Swagger Documentation — Автогенерация API документации

## Overview

Автоматическая генерация OpenAPI 3.0 спецификации для cstatiWarehouse backend API с интерактивной Swagger UI документацией. Обеспечивает актуальную, интерактивную и машиночитаемую документацию API.

## Goals

1. **Автоматическая генерация** документации из кода
2. **Интерактивная документация** с возможностью тестирования
3. **Актуальность** - документация всегда соответствует коду
4. **Типобезопасность** - валидация запросов/ответов
5. **Client generation** - автогенерация клиентов для iOS/Web

## Tools & Libraries

### Backend (Go)
- **swaggo/swag** - генератор OpenAPI из комментариев
- **swaggo/http-swagger** - Swagger UI middleware
- **go-openapi/spec** - работа со спецификацией

### Installation

```bash
# Install swag CLI
go install github.com/swaggo/swag/cmd/swag@latest

# Add dependencies
go get -u github.com/swaggo/http-swagger
go get -u github.com/swaggo/files
```

## Implementation

### 1. Main API Documentation

**`backend/cmd/server/main.go`** (add annotations):

```go
package main

// @title cstatiWarehouse API
// @version 1.0
// @description Backend API для системы управления складом
// @termsOfService https://cstati-warehouse.app/terms

// @contact.name API Support
// @contact.url https://cstati-warehouse.app/support
// @contact.email support@cstati-warehouse.app

// @license.name MIT
// @license.url https://opensource.org/licenses/MIT

// @host api.cstati-warehouse.app
// @BasePath /api/v1

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.

// @schemes https http
// @produce json
// @consumes json

func main() {
    if err := run(); err != nil {
        log.Fatal(err)
    }
}
```

### 2. Handler Annotations

**`backend/internal/adapter/httpapi/auth_handler.go`**:

```go
// Register godoc
// @Summary Регистрация нового пользователя
// @Description Создает нового пользователя с email и паролем
// @Tags auth
// @Accept json
// @Produce json
// @Param request body registerRequest true "Данные регистрации"
// @Success 201 {object} authResponse "Успешная регистрация"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 409 {object} errorResponse "Email уже используется"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /auth/register [post]
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Login godoc
// @Summary Вход в систему
// @Description Аутентификация пользователя по email и паролю
// @Tags auth
// @Accept json
// @Produce json
// @Param request body loginRequest true "Данные входа"
// @Success 200 {object} authResponse "Успешный вход"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Неверные учетные данные"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /auth/login [post]
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// UpdateProfile godoc
// @Summary Обновление профиля
// @Description Обновляет имя пользователя
// @Tags auth
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body updateProfileRequest true "Новые данные профиля"
// @Success 200 {object} userResponse "Обновленный профиль"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /auth/profile [put]
func (h *AuthHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Refresh godoc
// @Summary Обновление токенов
// @Description Обновляет access и refresh токены
// @Tags auth
// @Accept json
// @Produce json
// @Param request body refreshRequest true "Refresh token"
// @Success 200 {object} authResponse "Новые токены"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Неверный refresh token"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /auth/refresh [post]
func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}
```

**`backend/internal/adapter/httpapi/warehouse_handler.go`**:

```go
// ListItems godoc
// @Summary Список позиций склада
// @Description Возвращает список активных или архивных позиций организации
// @Tags warehouse
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param orgID path string true "ID организации" format(uuid)
// @Param scope query string false "Область: active или history" Enums(active, history) default(active)
// @Success 200 {array} itemDTO "Список позиций"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 403 {object} errorResponse "Доступ запрещен"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /organizations/{orgID}/items [get]
func (h *WarehouseHandler) ListItems(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Create godoc
// @Summary Создание позиции
// @Description Создает новую позицию на складе
// @Tags warehouse
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param orgID path string true "ID организации" format(uuid)
// @Param request body createItemRequest true "Данные позиции"
// @Success 201 {object} itemDTO "Созданная позиция"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 403 {object} errorResponse "Доступ запрещен"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /organizations/{orgID}/items [post]
func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Update godoc
// @Summary Обновление позиции
// @Description Обновляет существующую позицию
// @Tags warehouse
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param itemID path string true "ID позиции" format(uuid)
// @Param request body updateItemRequest true "Обновленные данные"
// @Success 200 {object} itemDTO "Обновленная позиция"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 403 {object} errorResponse "Доступ запрещен"
// @Failure 404 {object} errorResponse "Позиция не найдена"
// @Failure 409 {object} errorResponse "Конфликт версий"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /items/{itemID} [put]
func (h *WarehouseHandler) Update(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Archive godoc
// @Summary Архивация позиции
// @Description Архивирует позицию с указанием причины
// @Tags warehouse
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param itemID path string true "ID позиции" format(uuid)
// @Param request body archiveRequest true "Данные архивации"
// @Success 200 {object} archiveResponse "Результат архивации"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 403 {object} errorResponse "Доступ запрещен"
// @Failure 404 {object} errorResponse "Позиция не найдена"
// @Failure 409 {object} errorResponse "Конфликт версий"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /items/{itemID}/archive [post]
func (h *WarehouseHandler) Archive(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}
```

**`backend/internal/adapter/httpapi/organization_handler.go`**:

```go
// ListMyOrganizations godoc
// @Summary Мои организации
// @Description Возвращает список организаций пользователя
// @Tags organizations
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {array} organizationSummaryDTO "Список организаций"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /organizations/my [get]
func (h *OrganizationHandler) ListMyOrganizations(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// Create godoc
// @Summary Создание организации
// @Description Создает новую организацию
// @Tags organizations
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body createOrganizationRequest true "Данные организации"
// @Success 201 {object} organizationDTO "Созданная организация"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /organizations [post]
func (h *OrganizationHandler) Create(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}

// JoinByCode godoc
// @Summary Присоединение к организации
// @Description Присоединяется к организации по коду приглашения
// @Tags organizations
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body joinByCodeRequest true "Код приглашения"
// @Success 200 {object} organizationDTO "Организация"
// @Failure 400 {object} errorResponse "Неверный запрос"
// @Failure 401 {object} errorResponse "Требуется авторизация"
// @Failure 404 {object} errorResponse "Неверный код"
// @Failure 409 {object} errorResponse "Уже в организации"
// @Failure 500 {object} errorResponse "Внутренняя ошибка сервера"
// @Router /organizations/join [post]
func (h *OrganizationHandler) JoinByCode(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}
```

### 3. DTO Models

**`backend/internal/adapter/httpapi/dto.go`**:

```go
package httpapi

// Request DTOs

// registerRequest represents registration request
// @Description Данные для регистрации нового пользователя
type registerRequest struct {
    Email    string `json:"email" example:"user@example.com" validate:"required,email"`
    Password string `json:"password" example:"SecurePass123!" validate:"required,min=8"`
    Name     string `json:"name" example:"Иван Иванов" validate:"required"`
}

// loginRequest represents login request
// @Description Данные для входа в систему
type loginRequest struct {
    Email    string `json:"email" example:"user@example.com" validate:"required,email"`
    Password string `json:"password" example:"SecurePass123!" validate:"required"`
}

// createItemRequest represents item creation request
// @Description Данные для создания новой позиции
type createItemRequest struct {
    Name              string  `json:"name" example:"Молоко 3.2%" validate:"required"`
    Category          string  `json:"category" example:"Молочные продукты"`
    Quantity          int     `json:"quantity" example:"50" validate:"required,min=0"`
    MeasureUnit       string  `json:"measure_unit" example:"liters" validate:"required"`
    ExpiresAt         *string `json:"expires_at" example:"2024-12-31T23:59:59Z"`
    Location          string  `json:"location" example:"Холодильник #1"`
    Notes             string  `json:"notes" example:"Партия #12345"`
    PhotoURL          string  `json:"photo_url" example:"https://cdn.example.com/image.jpg"`
    ParentItemID      *string `json:"parent_item_id" example:"550e8400-e29b-41d4-a716-446655440000"`
    AmountPerPackage  float64 `json:"amount_per_package" example:"1.0"`
    VolumeLiters      *int    `json:"volume_liters" example:"1000"`
}

// Response DTOs

// authResponse represents authentication response
// @Description Ответ с токенами аутентификации
type authResponse struct {
    AccessToken  string      `json:"access_token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
    RefreshToken string      `json:"refresh_token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
    User         userDTO     `json:"user"`
}

// userDTO represents user data
// @Description Данные пользователя
type userDTO struct {
    ID        string `json:"id" example:"550e8400-e29b-41d4-a716-446655440000"`
    Email     string `json:"email" example:"user@example.com"`
    Name      string `json:"name" example:"Иван Иванов"`
    CreatedAt string `json:"created_at" example:"2024-01-15T10:30:00Z"`
}

// itemDTO represents warehouse item
// @Description Позиция склада
type itemDTO struct {
    ID               string     `json:"id" example:"550e8400-e29b-41d4-a716-446655440000"`
    Name             string     `json:"name" example:"Молоко 3.2%"`
    Category         string     `json:"category" example:"Молочные продукты"`
    Quantity         int        `json:"quantity" example:"50"`
    MeasureUnit      string     `json:"measure_unit" example:"liters"`
    ExpiresAt        *string    `json:"expires_at" example:"2024-12-31T23:59:59Z"`
    Location         string     `json:"location" example:"Холодильник #1"`
    Notes            string     `json:"notes" example:"Партия #12345"`
    PhotoURL         string     `json:"photo_url" example:"https://cdn.example.com/image.jpg"`
    Status           string     `json:"status" example:"in_stock"`
    ParentItemID     *string    `json:"parent_item_id"`
    Variants         []itemDTO  `json:"variants,omitempty"`
    CreatedAt        string     `json:"created_at" example:"2024-01-15T10:30:00Z"`
    UpdatedAt        string     `json:"updated_at" example:"2024-01-15T10:30:00Z"`
}

// errorResponse represents error response
// @Description Ответ с ошибкой
type errorResponse struct {
    Error   string `json:"error" example:"invalid_request"`
    Message string `json:"message" example:"Неверный формат запроса"`
}
```

### 4. Generate Documentation

**Makefile** (add):

```makefile
.PHONY: swagger
swagger:
	swag init -g cmd/server/main.go -o docs --parseDependency --parseInternal

.PHONY: swagger-fmt
swagger-fmt:
	swag fmt

.PHONY: serve-docs
serve-docs: swagger
	@echo "Swagger UI available at http://localhost:8080/swagger/index.html"
	go run cmd/server/main.go
```

**Generate docs**:

```bash
# Generate OpenAPI spec
make swagger

# Format swagger comments
make swagger-fmt

# Run server with docs
make serve-docs
```

### 5. Swagger UI Integration

**`backend/internal/adapter/httpapi/router.go`** (update):

```go
package httpapi

import (
    "net/http"
    
    "github.com/go-chi/chi/v5"
    httpSwagger "github.com/swaggo/http-swagger"
    
    _ "cstatiWarehouse/docs" // Import generated docs
)

func NewRouter(deps RouterDeps) http.Handler {
    r := chi.NewRouter()
    
    // ... existing middleware ...
    
    // Swagger UI
    r.Get("/swagger/*", httpSwagger.Handler(
        httpSwagger.URL("/swagger/doc.json"),
        httpSwagger.DeepLinking(true),
        httpSwagger.DocExpansion("list"),
        httpSwagger.DomID("swagger-ui"),
    ))
    
    // Serve OpenAPI spec
    r.Get("/swagger/doc.json", func(w http.ResponseWriter, r *http.Request) {
        http.ServeFile(w, r, "./docs/swagger.json")
    })
    
    // ... existing routes ...
    
    return r
}
```

### 6. Generated Files Structure

After running `swag init`, you'll get:

```
backend/
├── docs/
│   ├── docs.go          # Generated Go code
│   ├── swagger.json     # OpenAPI 3.0 spec (JSON)
│   └── swagger.yaml     # OpenAPI 3.0 spec (YAML)
```

## Advanced Features

### 1. Custom Types

**Enums**:

```go
// ItemStatus represents item status
// @Description Статус позиции
type ItemStatus string

const (
    // @Description Позиция на складе
    ItemStatusInStock ItemStatus = "in_stock"
    
    // @Description Позиция архивирована
    ItemStatusArchived ItemStatus = "archived"
)
```

**Custom Validation**:

```go
// createItemRequest with validation
type createItemRequest struct {
    Name     string `json:"name" validate:"required,min=1,max=255" example:"Молоко"`
    Quantity int    `json:"quantity" validate:"required,min=0,max=999999" example:"50"`
    Email    string `json:"email" validate:"required,email" example:"user@example.com"`
}
```

### 2. Response Examples

```go
// ListItems godoc
// @Success 200 {array} itemDTO "Список позиций"
// @Success 200 {object} object{items=[]itemDTO,total=int} "Список с пагинацией"
// @Header 200 {string} X-Total-Count "Общее количество"
// @Example response 200 application/json {"items": [{"id": "123", "name": "Молоко"}], "total": 1}
```

### 3. File Upload

```go
// UploadImage godoc
// @Summary Загрузка изображения
// @Description Загружает изображение позиции
// @Tags uploads
// @Accept multipart/form-data
// @Produce json
// @Security BearerAuth
// @Param file formData file true "Файл изображения"
// @Success 200 {object} uploadResponse "URL загруженного файла"
// @Router /uploads [post]
func (h *UploadsHandler) UploadImage(w http.ResponseWriter, r *http.Request) {
    // ... implementation
}
```

### 4. Pagination

```go
// ListItems godoc
// @Param page query int false "Номер страницы" default(1) minimum(1)
// @Param per_page query int false "Элементов на странице" default(20) minimum(1) maximum(100)
// @Success 200 {object} paginatedResponse{items=[]itemDTO}
```

## Client Generation

### iOS Client (Swift)

**Using OpenAPI Generator**:

```bash
# Install OpenAPI Generator
brew install openapi-generator

# Generate Swift client
openapi-generator generate \
  -i http://localhost:8080/swagger/doc.json \
  -g swift5 \
  -o ios/Generated/APIClient \
  --additional-properties=projectName=CstatiWarehouseAPI
```

**Generated client usage**:

```swift
import CstatiWarehouseAPI

let api = DefaultAPI()

// Login
api.authLoginPost(loginRequest: LoginRequest(
    email: "user@example.com",
    password: "password"
)) { result in
    switch result {
    case .success(let response):
        print("Access token: \(response.accessToken)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### TypeScript Client (Web)

```bash
# Generate TypeScript client
openapi-generator generate \
  -i http://localhost:8080/swagger/doc.json \
  -g typescript-axios \
  -o web/src/generated/api
```

## Testing with Swagger UI

### 1. Access Swagger UI

Navigate to: `http://localhost:8080/swagger/index.html`

### 2. Authorize

1. Click "Authorize" button
2. Enter: `Bearer <your_jwt_token>`
3. Click "Authorize"

### 3. Test Endpoints

1. Expand endpoint (e.g., `POST /auth/login`)
2. Click "Try it out"
3. Fill in request body
4. Click "Execute"
5. View response

## CI/CD Integration

### GitHub Actions

**`.github/workflows/swagger.yml`**:

```yaml
name: Swagger Documentation

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Install swag
        run: go install github.com/swaggo/swag/cmd/swag@latest
      
      - name: Generate Swagger docs
        run: |
          cd backend
          swag init -g cmd/server/main.go -o docs --parseDependency --parseInternal
      
      - name: Validate OpenAPI spec
        run: |
          npm install -g @apidevtools/swagger-cli
          swagger-cli validate backend/docs/swagger.json
      
      - name: Upload docs artifact
        uses: actions/upload-artifact@v3
        with:
          name: swagger-docs
          path: backend/docs/
      
      - name: Deploy to GitHub Pages
        if: github.ref == 'refs/heads/main'
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./backend/docs
```

## Best Practices

1. **Keep annotations close to code** - easier to maintain
2. **Use examples** - helps developers understand expected format
3. **Document all error cases** - 400, 401, 403, 404, 409, 500
4. **Use tags** to group related endpoints
5. **Version your API** - /api/v1, /api/v2
6. **Validate generated spec** - use swagger-cli
7. **Auto-generate clients** - keep iOS/Web clients in sync
8. **Update docs in CI/CD** - fail build if docs are outdated
9. **Host docs publicly** - GitHub Pages, Netlify
10. **Use security schemes** - document authentication

## Monitoring

### Track API Usage

```go
// Middleware to track endpoint usage
func trackAPIUsage(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Log endpoint, method, response time
        start := time.Now()
        next.ServeHTTP(w, r)
        duration := time.Since(start)
        
        log.Printf("API: %s %s - %v", r.Method, r.URL.Path, duration)
    })
}
```

### Deprecation Warnings

```go
// DeprecatedEndpoint godoc
// @Summary Old endpoint (deprecated)
// @Description This endpoint is deprecated. Use /api/v2/items instead
// @Deprecated
// @Tags warehouse
// @Router /api/v1/old-items [get]
func (h *Handler) DeprecatedEndpoint(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("X-API-Warn", "This endpoint is deprecated")
    // ... implementation
}
```

## Troubleshooting

### Common Issues

1. **Docs not updating**:
   ```bash
   # Clean and regenerate
   rm -rf docs/
   swag init -g cmd/server/main.go -o docs
   ```

2. **Import cycle**:
   - Move DTOs to separate package
   - Use `--parseInternal` flag

3. **Missing types**:
   - Add `--parseDependency` flag
   - Import package in main.go

4. **Invalid spec**:
   ```bash
   # Validate
   swagger-cli validate docs/swagger.json
   ```

## References

- [Swaggo Documentation](https://github.com/swaggo/swag)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [OpenAPI Generator](https://openapi-generator.tech/)
- [API Design Best Practices](https://swagger.io/resources/articles/best-practices-in-api-design/)
