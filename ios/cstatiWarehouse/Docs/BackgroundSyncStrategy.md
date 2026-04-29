# Стратегия фоновой синхронизации

## Обзор

Фоновая синхронизация обеспечивает актуальность данных при переходах приложения между состояниями.

## Точки синхронизации

### 1. Переход в фон (sceneDidEnterBackground)
- Сохранить текущее состояние в кеш
- Поставить pending мутации в очередь
- Зарегистрировать background task для завершения отправки

### 2. Возврат на передний план (sceneWillEnterForeground)
- Проверить актуальность кеша (TTL)
- Запустить обработку очереди мутаций
- Обновить данные если кеш устарел

### 3. Периодическая синхронизация (BGAppRefreshTask)
- Регистрация: `BGTaskScheduler.shared.register(forTaskWithIdentifier:)`
- Частота: каждые 15 минут (минимум для iOS)
- Действия: обновить критичные данные (позиции склада, уведомления)

## Реализация

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "ru.cstati.warehouse.refresh",
        using: nil
    ) { task in
        self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
}

func handleAppRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh() // Планируем следующий запуск
    
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    
    task.expirationHandler = {
        queue.cancelAllOperations()
    }
    
    let operation = RefreshDataOperation()
    operation.completionBlock = {
        task.setTaskCompleted(success: !operation.isCancelled)
    }
    
    queue.addOperation(operation)
}

func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "ru.cstati.warehouse.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    
    try? BGTaskScheduler.shared.submit(request)
}
```

## Info.plist

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>ru.cstati.warehouse.refresh</string>
</array>
```

## Приоритеты синхронизации

1. **Критичные**: Позиции склада, уведомления о сроках годности
2. **Важные**: Список организаций, участники
3. **Низкие**: Аналитика, история архивации

## Обработка ошибок

- Сетевые ошибки: повторить через экспоненциальную задержку
- Ошибки авторизации: очистить токены, показать экран входа
- Конфликты данных: применить стратегию разрешения (last-write-wins или manual merge)
