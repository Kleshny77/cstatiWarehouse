# Стратегия инвалидации кеша

## Обзор

Стратегия определяет когда и как инвалидировать закешированные данные для обеспечения актуальности.

## TTL (Time To Live)

### Расширение OfflineCacheEntry

```swift
struct OfflineCacheEntry {
    let key: String
    let data: Data
    let cachedAt: Date
    let ttl: TimeInterval // Время жизни в секундах
    
    var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
}
```

### TTL по типам данных

| Тип данных | TTL | Обоснование |
|-----------|-----|-------------|
| Позиции склада (активные) | 5 минут | Часто изменяются |
| История архивации | 15 минут | Редко изменяется |
| Список организаций | 30 минут | Стабильные данные |
| Участники организации | 10 минут | Средняя частота изменений |
| Аналитика | 1 час | Агрегированные данные |

## Стратегии инвалидации

### 1. Time-based (по времени)
```swift
func get<T: Decodable>(key: String, ttl: TimeInterval) -> T? {
    guard let entry = storage.getEntry(key: key) else { return nil }
    
    if entry.isStale {
        storage.remove(key: key)
        return nil
    }
    
    return try? JSONDecoder().decode(T.self, from: entry.data)
}
```

### 2. Event-based (по событиям)
Инвалидация при определённых действиях:

```swift
// После создания/обновления/удаления позиции
func itemMutated(organizationID: UUID) {
    let mineKey = OfflineCacheKeys.warehouseActiveItems(organizationID: organizationID, scope: .mine)
    let allKey = OfflineCacheKeys.warehouseActiveItems(organizationID: organizationID, scope: .all)
    
    storage.remove(key: mineKey)
    storage.remove(key: allKey)
}

// После смены организации
func organizationChanged() {
    storage.removeAll(matching: "warehouse.activeItems.*")
}
```

### 3. Manual (ручная)
Pull-to-refresh всегда инвалидирует кеш:

```swift
func performPullToRefresh() async {
    guard let orgID = activeOrganization?.organization.id else { return }
    
    // Инвалидируем кеш
    let key = OfflineCacheKeys.warehouseActiveItems(organizationID: orgID, scope: scope)
    storage.remove(key: key)
    
    // Загружаем свежие данные
    await loadItems(force: true)
}
```

## Проверка актуальности

### При загрузке данных

```swift
func loadItems(organizationID: UUID, scope: WarehouseScope, force: Bool = false) {
    let key = OfflineCacheKeys.warehouseActiveItems(organizationID: organizationID, scope: scope)
    
    // Проверяем кеш если не force
    if !force, let cached: [Item] = cacheStore.get(key: key, ttl: 300) {
        self.items = cached
        return
    }
    
    // Загружаем с сервера
    warehouseService.fetchActiveItems(organizationID: organizationID, scope: scope) { result in
        switch result {
        case .success(let items):
            self.items = items
            self.cacheStore.set(key: key, value: items, ttl: 300)
        case .failure(let error):
            // Если есть устаревший кеш - показываем его с предупреждением
            if let stale: [Item] = cacheStore.get(key: key, ttl: .infinity) {
                self.items = stale
                self.showStaleDataWarning()
            }
        }
    }
}
```

## Индикаторы устаревших данных

### UI элементы
- Баннер "Данные могут быть устаревшими" при показе stale кеша
- Иконка обновления в navigation bar
- Timestamp последнего обновления

### Реализация

```swift
struct StaleDataBanner: View {
    let lastUpdated: Date
    let onRefresh: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("Обновлено \(lastUpdated.formattedRelative())")
                .font(.caption)
            
            Spacer()
            
            Button("Обновить", action: onRefresh)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.orange.opacity(0.1))
    }
}
```

## Очистка кеша

### Автоматическая очистка
- При выходе из аккаунта: удалить весь кеш
- При переполнении: удалить самые старые записи (LRU)
- Периодическая очистка: раз в неделю удалять записи старше 7 дней

### Ручная очистка
Настройки → Очистить кеш

```swift
func clearAllCache() {
    storage.removeAll()
    // Показать toast "Кеш очищен"
}
```
