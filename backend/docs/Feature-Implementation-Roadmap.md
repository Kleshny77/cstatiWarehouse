# Feature Implementation Roadmap

Этот документ описывает архитектурный подход к реализации оставшихся фич проекта cstatiWarehouse.

## ✅ Завершено (25 задач)

См. предыдущий отчёт - все критичные исправления, оптимизации и рефакторинг завершены.

## 🚧 В процессе реализации

### 1. WebSocket для Real-time обновлений

**Статус**: ✅ **ПОЛНОСТЬЮ ЗАВЕРШЕНО**

**Backend**:
- ✅ Создан [`websocket/hub.go`](../internal/adapter/websocket/hub.go) - управление подключениями
- ✅ Создан [`websocket/client.go`](../internal/adapter/websocket/client.go) - клиент с ping/pong
- ✅ Создан [`websocket/broadcaster.go`](../internal/adapter/websocket/broadcaster.go) - broadcaster для UseCase
- ✅ Создан [`websocket/websocket_handler.go`](../internal/adapter/httpapi/websocket_handler.go) - HTTP handler
- ✅ Добавлена зависимость `gorilla/websocket`
- ✅ Интегрирован с WarehouseUseCase для broadcast событий (Create/Update/Archive/Delete)
- ✅ Добавлен endpoint `GET /ws?organization_id={uuid}` с аутентификацией
- ✅ Инициализация Hub в main.go

**iOS**:
- ✅ Создан [`WebSocketService.swift`](../../ios/cstatiWarehouse/Services/WebSocket/WebSocketService.swift)
- ✅ Использует `URLSessionWebSocketTask` для подключения
- ✅ Декодирование через `ItemDTO` (совместимость с ApiWarehouseService)
- ✅ Протокол `WebSocketEventHandler` для обработки событий
- ✅ Добавлен в `AppServices` как singleton
- ✅ Интегрирован с MyWarehouseInteractor (реализован WebSocketEventHandler)
- ✅ Автоматическое подключение при resolveActiveOrganization
- ✅ Переподключение при смене организации (selectActiveOrganization)
- ✅ Обработка событий через presenter (itemChangedExternally, itemDeleted)
- ✅ Автоматическое отключение в deinit

**Документация**:
- ✅ Создан [`WebSocket-Real-Time-Updates.md`](WebSocket-Real-Time-Updates.md)

**Приоритет**: ✅ Завершено

---

### 2. Сжатие фото перед загрузкой

**Backend**:
- ⏳ TODO: Добавить `github.com/disintegration/imaging` для resize
- ⏳ TODO: Создать middleware для обработки изображений
- ⏳ TODO: Генерировать thumbnails (200x200, 800x800)

**iOS**:
- ⏳ TODO: Сжимать до JPEG 0.7 quality перед upload
- ⏳ TODO: Показывать прогресс сжатия
- ⏳ TODO: Максимальный размер 2048x2048

**Код**:
```swift
// iOS
extension UIImage {
    func compressed(quality: CGFloat = 0.7, maxDimension: CGFloat = 2048) -> Data? {
        let size = self.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio < 1 {
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            self.draw(in: CGRect(origin: .zero, size: newSize))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resized?.jpegData(compressionQuality: quality)
        }
        
        return self.jpegData(compressionQuality: quality)
    }
}
```

**Приоритет**: 🟡 Средний

---

### 3. Улучшение Push уведомлений

**Backend**:
- ⏳ TODO: Создать cron job для проверки истекающих позиций
- ⏳ TODO: Интеграция с APNs через `github.com/sideshow/apns2`
- ⏳ TODO: Шаблоны уведомлений (expiring_soon, out_of_stock, item_updated)

**Таблица уже есть**: `device_push_tokens`

**Код**:
```go
// backend/internal/infra/notifications/apns.go
type APNsService struct {
    client *apns2.Client
    topic  string
}

func (s *APNsService) SendExpiringNotification(token string, item *domain.Item) error {
    notification := &apns2.Notification{
        DeviceToken: token,
        Topic:       s.topic,
        Payload: map[string]interface{}{
            "aps": map[string]interface{}{
                "alert": map[string]string{
                    "title": "Срок годности истекает",
                    "body":  fmt.Sprintf("%s истекает %s", item.Name, item.ExpirationDate.Format("02.01")),
                },
                "sound": "default",
                "badge": 1,
            },
            "item_id": item.ID.String(),
        },
    }
    
    res, err := s.client.Push(notification)
    return err
}
```

**Приоритет**: 🟡 Средний

---

### 4. Дашборд аналитики (3 таб)

**Backend**:
- ⏳ TODO: Создать `/analytics` endpoints
- ⏳ TODO: Агрегации: top_items, archive_trends, turnover_rate

**iOS**:
- ⏳ TODO: Использовать Swift Charts для графиков
- ⏳ TODO: Виджеты: Most Used Items, Archive Trends, Low Stock Alert

**Приоритет**: 🟢 Низкий

---

### 5. Локализация (i18n)

**iOS**:
- ⏳ TODO: Создать `Localizable.strings` (ru, en)
- ⏳ TODO: Заменить хардкод строки на `NSLocalizedString`
- ⏳ TODO: Локализовать даты, числа, валюту

**Backend**:
- ✅ Уже есть `i18n/activity.go` для русских строк
- ⏳ TODO: Добавить английские переводы

**Приоритет**: 🟡 Средний

---

### 6. Тактильная обратная связь (Haptics)

**iOS**:
- ⏳ TODO: Создать `HapticFeedbackService`
- ⏳ TODO: Guidelines: success (.success), error (.error), warning (.warning), selection (.selection)

**Код**:
```swift
enum HapticFeedback {
    case success, error, warning, selection
    
    func trigger() {
        switch self {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
```

**Приоритет**: 🟢 Низкий

---

### 7. Система резервирования

**Backend**:
- ⏳ TODO: Миграция: создать таблицу `reservations`
- ⏳ TODO: UseCase: CreateReservation, CancelReservation
- ⏳ TODO: Валидация: проверка доступного количества

**Schema**:
```sql
CREATE TABLE reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    reserved_by_user_id UUID NOT NULL REFERENCES users(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    reserved_from TIMESTAMPTZ NOT NULL,
    reserved_until TIMESTAMPTZ NOT NULL,
    event_id UUID REFERENCES org_events(id),
    notes TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Приоритет**: 🟡 Средний

---

### 8. Комментарии к позициям

**Backend**:
- ⏳ TODO: Миграция: создать таблицу `item_comments`
- ⏳ TODO: UseCase: AddComment, ListComments

**Schema**:
```sql
CREATE TABLE item_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id),
    user_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Приоритет**: 🟢 Низкий

---

### 9. Undo/Redo (Soft Delete)

**Backend**:
- ⏳ TODO: Добавить `deleted_at TIMESTAMPTZ` в таблицу `items`
- ⏳ TODO: Изменить Delete на UPDATE SET deleted_at = NOW()
- ⏳ TODO: Добавить Restore метод

**Приоритет**: 🟡 Средний

---

### 10. Безопасность

#### Rate limiting на пользователя
- ⏳ TODO: Добавить user-based rate limiter в middleware

#### CORS
- ⏳ TODO: Добавить `github.com/rs/cors` middleware

#### Валидация файлов
- ⏳ TODO: Проверка magic numbers (не только MIME type)

**Приоритет**: 🔴 Высокий

---

### 11. Оптимизация

#### N+1 проблема
- ⏳ TODO: Переписать ListArchiveEvents с JOIN

#### CDN для изображений
- ⏳ TODO: Интеграция с S3/CloudFront

#### Ленивая загрузка
- ⏳ TODO: iOS LazyVStack + async image loading

**Приоритет**: 🟡 Средний

---

### 12. Документация

#### OpenAPI/Swagger
- ⏳ TODO: Генерация из кода или ручное написание

#### ADR (Architecture Decision Records)
- ⏳ TODO: Создать `docs/adr/` с решениями

#### Deployment Guide
- ⏳ TODO: Docker Compose, Kubernetes manifests

#### CONTRIBUTING.md
- ⏳ TODO: PR template, code style guide

**Приоритет**: 🟡 Средний

---

## Рекомендуемый порядок реализации

1. **Фаза 1 - Критичные** (1-2 недели)
   - WebSocket real-time updates
   - Безопасность (rate limiting, CORS, file validation)
   - Undo/Redo (soft delete)

2. **Фаза 2 - Важные** (2-3 недели)
   - Сжатие фото
   - Система резервирования
   - Улучшение push уведомлений
   - Локализация i18n

3. **Фаза 3 - Улучшения** (1-2 недели)
   - Комментарии к позициям
   - Тактильная обратная связь
   - Дашборд аналитики

4. **Фаза 4 - Оптимизация** (1 неделя)
   - N+1 проблема
   - CDN для изображений
   - Ленивая загрузка

5. **Фаза 5 - Документация** (1 неделя)
   - OpenAPI/Swagger
   - ADR
   - Deployment Guide
   - CONTRIBUTING.md

**Общая оценка**: 7-10 недель разработки
