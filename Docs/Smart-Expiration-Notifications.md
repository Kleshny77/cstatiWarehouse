# Smart Expiration Notifications — Умные напоминания об истечении срока годности

## Overview

Улучшенная система напоминаний об истечении срока годности с интеллектуальными алгоритмами, персонализацией и проактивными рекомендациями. Система помогает минимизировать потери от просроченных товаров и оптимизировать управление запасами.

## Current State vs Enhanced State

### Current Implementation
- ✅ Базовые локальные уведомления за 3 дня до истечения
- ✅ Ежедневная проверка в 10:00
- ✅ Простой список истекающих позиций
- ❌ Нет персонализации
- ❌ Нет приоритизации
- ❌ Нет рекомендаций по действиям
- ❌ Нет аналитики паттернов

### Enhanced Implementation
- ✅ Многоуровневая система напоминаний (7, 3, 1 день, день истечения)
- ✅ Персонализация по категориям и истории
- ✅ Приоритизация по стоимости и количеству
- ✅ Проактивные рекомендации (использование, заморозка, перемещение)
- ✅ Аналитика паттернов истечения
- ✅ Интеграция с резервированиями
- ✅ Push-уведомления с действиями
- ✅ Умная группировка уведомлений

## Notification Strategy

### Multi-Level Alerts

#### Level 1: Early Warning (7 days before)
**Purpose**: Планирование действий
**Target**: Владельцы и администраторы
**Content**: 
- "У вас 5 позиций истекают через неделю"
- Список категорий с количеством
- Рекомендация: "Запланируйте использование или перемещение"

**Example**:
```
🔔 Напоминание о сроке годности
Через 7 дней истекает срок у 5 позиций:
• Молочные продукты (3)
• Мясо (2)

💡 Рекомендация: Запланируйте использование или перемещение
```

#### Level 2: Action Required (3 days before)
**Purpose**: Срочные действия
**Target**: Все участники организации
**Content**:
- Детальный список позиций
- Приоритет по стоимости
- Конкретные действия (использовать, заморозить, переместить)

**Example**:
```
⚠️ Срочно: истекает через 3 дня
1. Молоко "Простоквашино" 3.2% - 20 л
   → Используйте в ближайшие дни
2. Говядина охлажденная - 5 кг
   → Приготовьте или заморозьте
```

#### Level 3: Critical (1 day before)
**Purpose**: Последний шанс
**Target**: Владельцы и администраторы
**Content**:
- Критический список
- Автоматические рекомендации
- Быстрые действия (архивировать, списать)

**Example**:
```
🚨 КРИТИЧНО: истекает завтра!
Молоко "Простоквашино" 3.2% - 20 л

Быстрые действия:
[Использовать] [Заморозить] [Архивировать]
```

#### Level 4: Expired (day of expiration)
**Purpose**: Немедленное действие
**Target**: Владельцы и администраторы
**Content**:
- Список просроченных позиций
- Автоматическое предложение архивации
- Отчет о потерях

**Example**:
```
❌ Истек срок годности
3 позиции требуют архивации:
• Молоко "Простоквашино" - 20 л
• Йогурт "Активиа" - 10 шт

[Архивировать все] [Просмотреть]
```

## Backend Implementation

### Enhanced Notification Service

**`backend/internal/usecase/expiration_notifications.go`**:

```go
package usecase

import (
    "context"
    "fmt"
    "sort"
    "time"
    
    "github.com/google/uuid"
    "cstatiWarehouse/internal/domain"
)

type ExpirationNotificationsUseCase struct {
    itemRepo      ItemRepository
    orgRepo       OrganizationRepository
    userRepo      UserRepository
    pushService   PushNotificationService
    analytics     AnalyticsService
}

type ExpirationLevel int

const (
    ExpirationLevelEarly    ExpirationLevel = 7  // 7 days
    ExpirationLevelAction   ExpirationLevel = 3  // 3 days
    ExpirationLevelCritical ExpirationLevel = 1  // 1 day
    ExpirationLevelExpired  ExpirationLevel = 0  // Today
)

type ExpiringItem struct {
    Item          *domain.Item
    DaysRemaining int
    Level         ExpirationLevel
    Priority      int // 0-100, based on value and quantity
    Recommendation string
}

func (uc *ExpirationNotificationsUseCase) ProcessExpirationNotifications(ctx context.Context) error {
    // Get all organizations
    orgs, err := uc.orgRepo.ListAll(ctx)
    if err != nil {
        return err
    }
    
    for _, org := range orgs {
        if err := uc.processOrganization(ctx, org.ID); err != nil {
            // Log error but continue with other organizations
            continue
        }
    }
    
    return nil
}

func (uc *ExpirationNotificationsUseCase) processOrganization(ctx context.Context, orgID uuid.UUID) error {
    // Get all active items
    items, err := uc.itemRepo.ListByOrganization(ctx, orgID, usecase.ItemFilter{
        IncludeArchived: false,
    })
    if err != nil {
        return err
    }
    
    // Group items by expiration level
    expiringByLevel := make(map[ExpirationLevel][]ExpiringItem)
    
    now := time.Now()
    for _, item := range items {
        if item.ExpiresAt == nil {
            continue
        }
        
        daysRemaining := int(item.ExpiresAt.Sub(now).Hours() / 24)
        
        var level ExpirationLevel
        switch {
        case daysRemaining <= 0:
            level = ExpirationLevelExpired
        case daysRemaining <= 1:
            level = ExpirationLevelCritical
        case daysRemaining <= 3:
            level = ExpirationLevelAction
        case daysRemaining <= 7:
            level = ExpirationLevelEarly
        default:
            continue // Not expiring soon
        }
        
        expiringItem := ExpiringItem{
            Item:          &item,
            DaysRemaining: daysRemaining,
            Level:         level,
            Priority:      uc.calculatePriority(&item),
            Recommendation: uc.generateRecommendation(&item, daysRemaining),
        }
        
        expiringByLevel[level] = append(expiringByLevel[level], expiringItem)
    }
    
    // Send notifications for each level
    for level, items := range expiringByLevel {
        if err := uc.sendLevelNotifications(ctx, orgID, level, items); err != nil {
            // Log error but continue
            continue
        }
    }
    
    // Update analytics
    uc.updateExpirationAnalytics(ctx, orgID, expiringByLevel)
    
    return nil
}

func (uc *ExpirationNotificationsUseCase) calculatePriority(item *domain.Item) int {
    // Priority based on:
    // 1. Quantity (more items = higher priority)
    // 2. Category (perishables = higher priority)
    // 3. Historical expiration rate
    
    priority := 0
    
    // Quantity factor (0-40 points)
    if item.Quantity > 100 {
        priority += 40
    } else if item.Quantity > 50 {
        priority += 30
    } else if item.Quantity > 10 {
        priority += 20
    } else {
        priority += 10
    }
    
    // Category factor (0-30 points)
    perishableCategories := []string{"молочные", "мясо", "рыба", "овощи", "фрукты"}
    for _, cat := range perishableCategories {
        if contains(item.Category, cat) {
            priority += 30
            break
        }
    }
    
    // Value factor (0-30 points) - would need price data
    // For now, use quantity as proxy
    if item.Quantity > 50 {
        priority += 30
    } else if item.Quantity > 20 {
        priority += 20
    } else {
        priority += 10
    }
    
    return min(priority, 100)
}

func (uc *ExpirationNotificationsUseCase) generateRecommendation(item *domain.Item, daysRemaining int) string {
    switch {
    case daysRemaining <= 0:
        return "Архивировать как просроченное"
    case daysRemaining == 1:
        if item.Quantity > 10 {
            return "Срочно используйте или заморозьте"
        }
        return "Используйте сегодня"
    case daysRemaining <= 3:
        if item.Quantity > 20 {
            return "Используйте в ближайшие дни или заморозьте"
        }
        return "Запланируйте использование"
    case daysRemaining <= 7:
        return "Запланируйте использование или перемещение"
    default:
        return "Мониторить"
    }
}

func (uc *ExpirationNotificationsUseCase) sendLevelNotifications(
    ctx context.Context,
    orgID uuid.UUID,
    level ExpirationLevel,
    items []ExpiringItem,
) error {
    if len(items) == 0 {
        return nil
    }
    
    // Sort by priority
    sort.Slice(items, func(i, j int) bool {
        return items[i].Priority > items[j].Priority
    })
    
    // Get organization members
    members, err := uc.orgRepo.ListMembers(ctx, orgID)
    if err != nil {
        return err
    }
    
    // Determine recipients based on level
    var recipients []uuid.UUID
    for _, member := range members {
        switch level {
        case ExpirationLevelEarly:
            // Only owners and admins
            if member.Role == domain.RoleOwner || member.Role == domain.RoleAdmin {
                recipients = append(recipients, member.UserID)
            }
        case ExpirationLevelAction, ExpirationLevelCritical, ExpirationLevelExpired:
            // All members
            recipients = append(recipients, member.UserID)
        }
    }
    
    // Build notification
    notification := uc.buildNotification(level, items)
    
    // Send push notifications
    for _, userID := range recipients {
        user, err := uc.userRepo.GetByID(ctx, userID)
        if err != nil {
            continue
        }
        
        // Check user preferences (would need preferences table)
        // For now, send to all
        
        if err := uc.pushService.Send(ctx, user.APNsToken, notification); err != nil {
            // Log error but continue
            continue
        }
    }
    
    return nil
}

func (uc *ExpirationNotificationsUseCase) buildNotification(
    level ExpirationLevel,
    items []ExpiringItem,
) PushNotification {
    var title, body string
    var badge int
    var sound string
    var category string
    
    switch level {
    case ExpirationLevelEarly:
        title = "📅 Напоминание о сроке годности"
        body = fmt.Sprintf("Через 7 дней истекает срок у %d позиций", len(items))
        sound = "default"
        category = "EXPIRATION_EARLY"
        badge = len(items)
        
    case ExpirationLevelAction:
        title = "⚠️ Требуется действие"
        body = fmt.Sprintf("Через 3 дня истекает срок у %d позиций", len(items))
        sound = "alert"
        category = "EXPIRATION_ACTION"
        badge = len(items)
        
    case ExpirationLevelCritical:
        title = "🚨 КРИТИЧНО"
        body = fmt.Sprintf("Завтра истекает срок у %d позиций!", len(items))
        sound = "critical"
        category = "EXPIRATION_CRITICAL"
        badge = len(items)
        
    case ExpirationLevelExpired:
        title = "❌ Истек срок годности"
        body = fmt.Sprintf("%d позиций требуют архивации", len(items))
        sound = "critical"
        category = "EXPIRATION_EXPIRED"
        badge = len(items)
    }
    
    // Add top 3 items to body
    if len(items) > 0 {
        body += "\n"
        for i := 0; i < min(3, len(items)); i++ {
            body += fmt.Sprintf("\n• %s", items[i].Item.Name)
        }
    }
    
    return PushNotification{
        Title:    title,
        Body:     body,
        Badge:    badge,
        Sound:    sound,
        Category: category,
        Data: map[string]interface{}{
            "type":  "expiration",
            "level": level,
            "count": len(items),
        },
    }
}

func (uc *ExpirationNotificationsUseCase) updateExpirationAnalytics(
    ctx context.Context,
    orgID uuid.UUID,
    expiringByLevel map[ExpirationLevel][]ExpiringItem,
) {
    // Track expiration patterns for analytics
    totalExpiring := 0
    for _, items := range expiringByLevel {
        totalExpiring += len(items)
    }
    
    // Would save to analytics table
    uc.analytics.RecordExpirationMetrics(ctx, orgID, ExpirationMetrics{
        Date:            time.Now(),
        TotalExpiring:   totalExpiring,
        EarlyWarning:    len(expiringByLevel[ExpirationLevelEarly]),
        ActionRequired:  len(expiringByLevel[ExpirationLevelAction]),
        Critical:        len(expiringByLevel[ExpirationLevelCritical]),
        Expired:         len(expiringByLevel[ExpirationLevelExpired]),
    })
}

// Helper functions
func contains(s, substr string) bool {
    return len(s) > 0 && len(substr) > 0 && 
           (s == substr || len(s) >= len(substr) && s[:len(substr)] == substr)
}

func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}
```

### Personalization Engine

**`backend/internal/usecase/expiration_personalization.go`**:

```go
package usecase

import (
    "context"
    "time"
    
    "github.com/google/uuid"
)

type ExpirationPersonalizationUseCase struct {
    historyRepo ExpirationHistoryRepository
    userRepo    UserRepository
}

type UserExpirationPreferences struct {
    UserID              uuid.UUID
    PreferredCategories []string // Categories user cares about most
    QuietHours          *QuietHours
    MinimumPriority     int // Only notify if priority >= this
    GroupNotifications  bool // Group multiple items into one notification
}

type QuietHours struct {
    Start time.Time // e.g., 22:00
    End   time.Time // e.g., 08:00
}

func (uc *ExpirationPersonalizationUseCase) GetUserPreferences(
    ctx context.Context,
    userID uuid.UUID,
) (*UserExpirationPreferences, error) {
    // Load from database or return defaults
    prefs := &UserExpirationPreferences{
        UserID:             userID,
        MinimumPriority:    30, // Default: medium priority
        GroupNotifications: true,
    }
    
    // Analyze user's historical interactions
    history, err := uc.historyRepo.GetUserHistory(ctx, userID, 90) // Last 90 days
    if err != nil {
        return prefs, nil // Return defaults on error
    }
    
    // Determine preferred categories based on what user interacts with most
    categoryFrequency := make(map[string]int)
    for _, event := range history {
        categoryFrequency[event.Category]++
    }
    
    // Sort and take top 5
    var topCategories []string
    for cat := range categoryFrequency {
        topCategories = append(topCategories, cat)
    }
    sort.Slice(topCategories, func(i, j int) bool {
        return categoryFrequency[topCategories[i]] > categoryFrequency[topCategories[j]]
    })
    
    if len(topCategories) > 5 {
        topCategories = topCategories[:5]
    }
    
    prefs.PreferredCategories = topCategories
    
    return prefs, nil
}

func (uc *ExpirationPersonalizationUseCase) ShouldNotifyUser(
    ctx context.Context,
    userID uuid.UUID,
    item *ExpiringItem,
) (bool, error) {
    prefs, err := uc.GetUserPreferences(ctx, userID)
    if err != nil {
        return true, nil // Default to notifying on error
    }
    
    // Check priority threshold
    if item.Priority < prefs.MinimumPriority {
        return false, nil
    }
    
    // Check quiet hours
    if prefs.QuietHours != nil {
        now := time.Now()
        if isInQuietHours(now, prefs.QuietHours) {
            return false, nil
        }
    }
    
    // Check preferred categories
    if len(prefs.PreferredCategories) > 0 {
        categoryMatch := false
        for _, cat := range prefs.PreferredCategories {
            if item.Item.Category == cat {
                categoryMatch = true
                break
            }
        }
        if !categoryMatch && item.Priority < 80 {
            // Only notify for non-preferred categories if high priority
            return false, nil
        }
    }
    
    return true, nil
}

func isInQuietHours(now time.Time, quiet *QuietHours) bool {
    hour := now.Hour()
    startHour := quiet.Start.Hour()
    endHour := quiet.End.Hour()
    
    if startHour < endHour {
        return hour >= startHour && hour < endHour
    }
    // Quiet hours span midnight
    return hour >= startHour || hour < endHour
}
```

### Cron Job Setup

**`backend/cmd/server/main.go`** (add):

```go
import (
    "github.com/robfig/cron/v3"
)

func setupExpirationNotifications(deps *Dependencies) {
    c := cron.New()
    
    // Run every day at 10:00 AM
    c.AddFunc("0 10 * * *", func() {
        ctx := context.Background()
        if err := deps.ExpirationNotificationsUC.ProcessExpirationNotifications(ctx); err != nil {
            log.Printf("Error processing expiration notifications: %v", err)
        }
    })
    
    // Run every 6 hours for critical items
    c.AddFunc("0 */6 * * *", func() {
        ctx := context.Background()
        // Process only critical and expired
        // Implementation similar but filtered
    })
    
    c.Start()
}
```

## iOS Implementation

### Enhanced Notification Handling

**`ios/cstatiWarehouse/Services/ShelfLife/EnhancedShelfLifeNotificationService.swift`**:

```swift
//
//  EnhancedShelfLifeNotificationService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import UserNotifications

final class EnhancedShelfLifeNotificationService {
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Schedule Notifications
    
    func scheduleExpirationNotifications(for items: [Item]) {
        // Cancel existing notifications
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Group items by expiration level
        let grouped = groupItemsByExpirationLevel(items)
        
        // Schedule for each level
        for (level, items) in grouped {
            scheduleNotification(for: level, items: items)
        }
    }
    
    private func groupItemsByExpirationLevel(_ items: [Item]) -> [ExpirationLevel: [Item]] {
        var grouped: [ExpirationLevel: [Item]] = [:]
        
        let now = Date()
        let calendar = Calendar.current
        
        for item in items {
            guard let expiresAt = item.expiresAt else { continue }
            
            let daysRemaining = calendar.dateComponents([.day], from: now, to: expiresAt).day ?? 0
            
            let level: ExpirationLevel
            switch daysRemaining {
            case ...0:
                level = .expired
            case 1:
                level = .critical
            case 2...3:
                level = .action
            case 4...7:
                level = .early
            default:
                continue
            }
            
            grouped[level, default: []].append(item)
        }
        
        return grouped
    }
    
    private func scheduleNotification(for level: ExpirationLevel, items: [Item]) {
        guard !items.isEmpty else { return }
        
        // Sort by priority
        let sortedItems = items.sorted { calculatePriority($0) > calculatePriority($1) }
        
        let content = UNMutableNotificationContent()
        content.title = level.title
        content.body = buildNotificationBody(for: level, items: sortedItems)
        content.badge = NSNumber(value: items.count)
        content.sound = level.sound
        content.categoryIdentifier = level.categoryIdentifier
        content.userInfo = [
            "type": "expiration",
            "level": level.rawValue,
            "count": items.count,
            "item_ids": sortedItems.prefix(10).map { $0.id.uuidString }
        ]
        
        // Determine trigger time
        let trigger = createTrigger(for: level)
        
        let request = UNNotificationRequest(
            identifier: "expiration_\(level.rawValue)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func buildNotificationBody(for level: ExpirationLevel, items: [Item]) -> String {
        var body = ""
        
        switch level {
        case .early:
            body = "Через 7 дней истекает срок у \(items.count) позиций"
        case .action:
            body = "Через 3 дня истекает срок у \(items.count) позиций"
        case .critical:
            body = "Завтра истекает срок у \(items.count) позиций!"
        case .expired:
            body = "\(items.count) позиций требуют архивации"
        }
        
        // Add top 3 items
        let topItems = items.prefix(3)
        if !topItems.isEmpty {
            body += "\n"
            for item in topItems {
                body += "\n• \(item.name)"
            }
        }
        
        return body
    }
    
    private func createTrigger(for level: ExpirationLevel) -> UNNotificationTrigger {
        var dateComponents = DateComponents()
        dateComponents.hour = 10 // 10:00 AM
        dateComponents.minute = 0
        
        switch level {
        case .early, .action:
            // Daily at 10:00 AM
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        case .critical:
            // Every 6 hours
            dateComponents.hour = nil
            return UNTimeIntervalNotificationTrigger(timeInterval: 6 * 3600, repeats: true)
        case .expired:
            // Every 3 hours
            return UNTimeIntervalNotificationTrigger(timeInterval: 3 * 3600, repeats: true)
        }
    }
    
    private func calculatePriority(_ item: Item) -> Int {
        var priority = 0
        
        // Quantity factor
        if item.quantity > 100 {
            priority += 40
        } else if item.quantity > 50 {
            priority += 30
        } else if item.quantity > 10 {
            priority += 20
        } else {
            priority += 10
        }
        
        // Category factor
        let perishableCategories = ["молочные", "мясо", "рыба", "овощи", "фрукты"]
        if perishableCategories.contains(where: { item.category.lowercased().contains($0) }) {
            priority += 30
        }
        
        // Value factor (using quantity as proxy)
        if item.quantity > 50 {
            priority += 30
        } else if item.quantity > 20 {
            priority += 20
        } else {
            priority += 10
        }
        
        return min(priority, 100)
    }
}

enum ExpirationLevel: String {
    case early = "early"
    case action = "action"
    case critical = "critical"
    case expired = "expired"
    
    var title: String {
        switch self {
        case .early: return "📅 Напоминание о сроке годности"
        case .action: return "⚠️ Требуется действие"
        case .critical: return "🚨 КРИТИЧНО"
        case .expired: return "❌ Истек срок годности"
        }
    }
    
    var sound: UNNotificationSound {
        switch self {
        case .early, .action: return .default
        case .critical, .expired: return .defaultCritical
        }
    }
    
    var categoryIdentifier: String {
        return "EXPIRATION_\(rawValue.uppercased())"
    }
}
```

### Notification Actions

**`ios/cstatiWarehouse/App/AppDelegate.swift`** (add):

```swift
func setupNotificationCategories() {
    // Early warning actions
    let viewAction = UNNotificationAction(
        identifier: "VIEW_EXPIRING",
        title: "Просмотреть",
        options: .foreground
    )
    
    let planAction = UNNotificationAction(
        identifier: "PLAN_USE",
        title: "Запланировать",
        options: .foreground
    )
    
    let earlyCategory = UNNotificationCategory(
        identifier: "EXPIRATION_EARLY",
        actions: [viewAction, planAction],
        intentIdentifiers: [],
        options: []
    )
    
    // Action required actions
    let useAction = UNNotificationAction(
        identifier: "USE_ITEMS",
        title: "Использовать",
        options: .foreground
    )
    
    let freezeAction = UNNotificationAction(
        identifier: "FREEZE_ITEMS",
        title: "Заморозить",
        options: .foreground
    )
    
    let actionCategory = UNNotificationCategory(
        identifier: "EXPIRATION_ACTION",
        actions: [viewAction, useAction, freezeAction],
        intentIdentifiers: [],
        options: []
    )
    
    // Critical actions
    let archiveAction = UNNotificationAction(
        identifier: "ARCHIVE_ITEMS",
        title: "Архивировать",
        options: [.destructive, .foreground]
    )
    
    let urgentUseAction = UNNotificationAction(
        identifier: "URGENT_USE",
        title: "Использовать срочно",
        options: .foreground
    )
    
    let criticalCategory = UNNotificationCategory(
        identifier: "EXPIRATION_CRITICAL",
        actions: [viewAction, archiveAction, urgentUseAction],
        intentIdentifiers: [],
        options: []
    )
    
    // Expired actions
    let archiveAllAction = UNNotificationAction(
        identifier: "ARCHIVE_ALL",
        title: "Архивировать все",
        options: [.destructive, .foreground]
    )
    
    let expiredCategory = UNNotificationCategory(
        identifier: "EXPIRATION_EXPIRED",
        actions: [viewAction, archiveAllAction],
        intentIdentifiers: [],
        options: []
    )
    
    UNUserNotificationCenter.current().setNotificationCategories([
        earlyCategory,
        actionCategory,
        criticalCategory,
        expiredCategory
    ])
}
```

### Analytics Dashboard Integration

**Expiration Analytics View**:

```swift
struct ExpirationAnalyticsView: View {
    let metrics: ExpirationMetrics
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Аналитика истечения срока")
                .font(.headline)
            
            // Summary cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Всего истекает",
                    value: "\(metrics.totalExpiring)",
                    color: .blue
                )
                
                MetricCard(
                    title: "Критично",
                    value: "\(metrics.critical)",
                    color: .red
                )
                
                MetricCard(
                    title: "Просрочено",
                    value: "\(metrics.expired)",
                    color: .gray
                )
            }
            
            // Trend chart
            ExpirationTrendChart(data: metrics.historicalData)
            
            // Category breakdown
