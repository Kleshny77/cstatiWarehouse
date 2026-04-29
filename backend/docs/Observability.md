# Observability Strategy

## Обзор

Стратегия наблюдаемости для отслеживания запросов через все слои приложения.

## Request ID

### Генерация и распространение

Request ID генерируется в middleware и передаётся через context во все слои:

```go
// middleware.go
func requestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = uuid.New().String()
        }
        
        ctx := context.WithValue(r.Context(), requestIDKey, requestID)
        w.Header().Set("X-Request-ID", requestID)
        
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### Structured Logging

Использование slog с request ID в каждом логе:

```go
// infra/logger/logger.go
package logger

import (
    "context"
    "log/slog"
    "os"
)

type contextKey string

const requestIDKey contextKey = "request_id"

// FromContext возвращает logger с request ID из контекста
func FromContext(ctx context.Context) *slog.Logger {
    requestID, _ := ctx.Value(requestIDKey).(string)
    if requestID == "" {
        return slog.Default()
    }
    
    return slog.Default().With("request_id", requestID)
}

// WithRequestID добавляет request ID в контекст
func WithRequestID(ctx context.Context, requestID string) context.Context {
    return context.WithValue(ctx, requestIDKey, requestID)
}

// GetRequestID извлекает request ID из контекста
func GetRequestID(ctx context.Context) string {
    requestID, _ := ctx.Value(requestIDKey).(string)
    return requestID
}
```

### Использование в слоях

#### HTTP Handler
```go
func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
    log := logger.FromContext(r.Context())
    log.Info("creating warehouse item")
    
    // ...
}
```

#### UseCase
```go
func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    log := logger.FromContext(ctx)
    log.Info("warehouse.create", "user_id", in.UserID, "org_id", in.OrganizationID)
    
    // ...
    
    if err != nil {
        log.Error("failed to create item", "err", err)
        return nil, err
    }
    
    log.Info("item created", "item_id", item.ID)
    return item, nil
}
```

#### Repository
```go
func (r *ItemRepo) Create(ctx context.Context, item *domain.Item) error {
    log := logger.FromContext(ctx)
    log.Debug("inserting item into database", "item_id", item.ID)
    
    // ...
}
```

## Метрики

### Prometheus metrics

```go
// infra/metrics/metrics.go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    HTTPRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path", "status"},
    )
    
    DBQueryDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "db_query_duration_seconds",
            Help: "Database query duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"operation", "table"},
    )
    
    ActiveUsers = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "active_users_total",
            Help: "Number of active users",
        },
    )
)
```

### Middleware для метрик

```go
func metricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        recorder := &statusRecorder{ResponseWriter: w, status: 200}
        next.ServeHTTP(recorder, r)
        
        duration := time.Since(start).Seconds()
        metrics.HTTPRequestDuration.WithLabelValues(
            r.Method,
            r.URL.Path,
            strconv.Itoa(recorder.status),
        ).Observe(duration)
    })
}
```

## Трейсинг

### OpenTelemetry (опционально)

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    ctx, span := otel.Tracer("warehouse").Start(ctx, "WarehouseUseCase.Create")
    defer span.End()
    
    span.SetAttributes(
        attribute.String("user_id", in.UserID.String()),
        attribute.String("org_id", in.OrganizationID.String()),
    )
    
    // ...
}
```

## Формат логов

### Development
```
2026-04-29T19:00:00Z INFO warehouse.create request_id=abc123 user_id=uuid org_id=uuid
```

### Production (JSON)
```json
{
  "time": "2026-04-29T19:00:00Z",
  "level": "INFO",
  "msg": "warehouse.create",
  "request_id": "abc123",
  "user_id": "uuid",
  "org_id": "uuid"
}
```

## Endpoints

- `GET /metrics` - Prometheus metrics
- `GET /health` - Health check
- `GET /ready` - Readiness probe
