# Стратегия обработки ошибок в cstatiWarehouse

## Принципы

1. **Консистентность**: Одинаковые типы ошибок обрабатываются одинаково во всём приложении
2. **Прозрачность**: Пользователь всегда понимает, что произошло и что делать дальше
3. **Graceful degradation**: Приложение продолжает работать даже при частичных сбоях
4. **Offline-first**: Сетевые ошибки не блокируют работу с кешированными данными

## Уровни серьёзности ошибок

### 1. Critical (Критические)
**Когда**: Невозможно продолжить работу, требуется действие пользователя
**UI**: Полноэкранный Alert с кнопкой действия
**Примеры**:
- Сессия истекла (401 Unauthorized)
- Нет доступа к организации (403 Forbidden)
- Критическая ошибка сервера (500)

**Реализация**:
```swift
presenter.showCriticalError(
    title: "Сессия истекла",
    message: "Войдите заново для продолжения работы",
    action: "Войти"
) {
    router.navigateToLogin()
}
```

### 2. High (Высокие)
**Когда**: Операция не выполнена, но можно повторить
**UI**: Alert с кнопками "Повторить" и "Отмена"
**Примеры**:
- Ошибка создания/обновления позиции
- Ошибка архивации
- Ошибка загрузки изображения

**Реализация**:
```swift
presenter.showRetryableError(
    message: "Не удалось сохранить изменения",
    retry: {
        interactor.saveItem()
    }
)
```

### 3. Medium (Средние)
**Когда**: Операция не выполнена, но есть fallback
**UI**: Passive banner (исчезает через 5 сек или по свайпу)
**Примеры**:
- Ошибка загрузки данных (показываем кеш)
- Ошибка синхронизации (отложим на потом)
- Ошибка загрузки категорий (используем локальные)

**Реализация**:
```swift
presenter.showPassiveBanner(
    message: "Не удалось загрузить данные. Показаны сохранённые.",
    action: "Повторить"
) {
    interactor.retry()
}
```

### 4. Low (Низкие)
**Когда**: Некритичная операция не выполнена
**UI**: Toast notification (исчезает через 3 сек)
**Примеры**:
- Ошибка отправки аналитики
- Ошибка предзагрузки изображений
- Ошибка обновления кеша

**Реализация**:
```swift
// Логируем, но не показываем пользователю
print("Non-critical error: \(error)")
```

## Типы ошибок по категориям

### Сетевые ошибки

| Ошибка | Уровень | UI | Действие |
|--------|---------|----|---------| 
| No internet | Medium | Passive banner | Показать кеш, retry |
| Timeout | Medium | Passive banner | Retry |
| 401 Unauthorized | Critical | Alert | Logout → Login |
| 403 Forbidden | Critical | Alert | Показать причину |
| 404 Not Found | High | Alert | Объяснить, что удалено |
| 409 Conflict | High | Alert | Показать актуальные данные |
| 500 Server Error | High | Alert | Retry |

### Валидационные ошибки

| Ошибка | Уровень | UI | Действие |
|--------|---------|----|---------| 
| Пустое поле | High | Inline error | Подсветить поле |
| Неверный формат | High | Inline error | Показать пример |
| Превышен лимит | High | Alert | Объяснить лимит |
| Дубликат | High | Alert | Предложить редактировать |

### Бизнес-логика ошибки

| Ошибка | Уровень | UI | Действие |
|--------|---------|----|---------| 
| Недостаточно прав | Critical | Alert | Объяснить роли |
| Позиция уже архивирована | High | Alert | Обновить список |
| Нельзя удалить родителя | High | Alert | Объяснить зависимости |
| Concurrent modification | High | Alert | Показать новую версию |

## Реализация в коде

### Presenter Protocol
```swift
protocol ErrorHandlingPresenter {
    func showCriticalError(title: String, message: String, action: String, handler: @escaping () -> Void)
    func showRetryableError(message: String, retry: @escaping () -> Void)
    func showPassiveBanner(message: String, action: String?, handler: (() -> Void)?)
    func showInlineError(field: String, message: String)
}
```

### Error Mapping
```swift
extension WarehouseError {
    var severity: ErrorSeverity {
        switch self {
        case .unauthorized:
            return .critical
        case .forbidden:
            return .critical
        case .notFound:
            return .high
        case .validationError:
            return .high
        case .concurrentModification:
            return .high
        case .networkError:
            return .medium
        case .serverError:
            return .high
        }
    }
    
    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        case .forbidden:
            return "Недостаточно прав для выполнения операции."
        case .notFound:
            return "Позиция не найдена. Возможно, она была удалена."
        case .validationError(let msg):
            return msg
        case .concurrentModification(let item):
            return "Позиция была изменена на сервере. Форма обновлена."
        case .networkError:
            return "Проверьте подключение к интернету."
        case .serverError(let msg):
            return msg.isEmpty ? "Ошибка сервера. Попробуйте позже." : msg
        }
    }
}
```

## Offline-режим

### Стратегия
1. **Чтение**: Всегда показываем кеш, если есть
2. **Запись**: Сохраняем в очередь мутаций, синхронизируем при появлении сети
3. **Индикация**: Показываем passive banner "Работаем офлайн"

### Очередь мутаций
```swift
// При ошибке сети сохраняем операцию
if case .networkError = error {
    offlineQueue.enqueue(operation)
    showPassiveBanner("Изменения сохранены. Синхронизируем при появлении сети.")
}
```

## Логирование

### Что логировать
- **Critical**: Всегда логировать с полным стеком
- **High**: Логировать с контекстом (user ID, org ID, item ID)
- **Medium**: Логировать кратко
- **Low**: Опционально

### Формат
```swift
logger.error("Failed to save item", metadata: [
    "userId": userId,
    "orgId": orgId,
    "itemId": itemId,
    "error": error.localizedDescription
])
```

## Тестирование

### Unit тесты
- Проверить маппинг каждого типа ошибки на severity
- Проверить user messages на читаемость
- Проверить retry логику

### UI тесты
- Проверить отображение каждого типа UI (Alert, Banner, Toast)
- Проверить dismiss логику
- Проверить accessibility

## Метрики

### Отслеживать
- Частота каждого типа ошибок
- Время до retry
- Success rate после retry
- Offline queue size

### Алерты
- Spike в 401 ошибках → проблема с токенами
- Spike в 500 ошибках → проблема на сервере
- Большая offline queue → проблема с синхронизацией
