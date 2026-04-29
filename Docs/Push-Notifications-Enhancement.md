# Push Notifications Enhancement

## Overview

Enhance push notifications with backend triggers for:
- **Expiration warnings** - Notify before items expire
- **Low stock alerts** - Alert when quantity is low
- **Team updates** - Notify team members of changes
- **Event reminders** - Remind about upcoming events

## Current Implementation

**iOS**: APNs token registration ([`backend/internal/adapter/httpapi/notifications_handler.go`](../backend/internal/adapter/httpapi/notifications_handler.go))
**Backend**: Token storage in `device_push_tokens` table

## Enhancement Plan

### 1. Expiration Warnings

**Trigger**: Daily cron job checks items expiring soon

```go
// backend/internal/usecase/notifications.go

type NotificationsUseCase struct {
    itemRepo      ItemRepository
    pushTokenRepo PushTokenRepository
    apnsClient    *apns2.Client
}

func (uc *NotificationsUseCase) SendExpirationWarnings(ctx context.Context) error {
    // Find items expiring in 3 days
    items, err := uc.itemRepo.FindExpiringSoon(ctx, 3*24*time.Hour)
    if err != nil {
        return err
    }
    
    for _, item := range items {
        // Get tokens for organization members
        tokens, err := uc.pushTokenRepo.GetByOrganization(ctx, item.OrganizationID)
        if err != nil {
            continue
        }
        
        // Send notification
        notification := &apns2.Notification{
            DeviceToken: token,
            Topic:       "com.example.cstatiWarehouse",
            Payload: map[string]interface{}{
                "aps": map[string]interface{}{
                    "alert": map[string]interface{}{
                        "title": "Item Expiring Soon",
                        "body":  fmt.Sprintf("%s expires in 3 days", item.Name),
                    },
                    "sound": "default",
                    "badge": 1,
                },
                "item_id": item.ID.String(),
                "type":    "expiration_warning",
            },
        }
        
        uc.apnsClient.Push(notification)
    }
    
    return nil
}
```

### 2. Low Stock Alerts

**Trigger**: When item quantity drops below threshold

```go
// In WarehouseUseCase.Archive

func (uc *WarehouseUseCase) Archive(ctx context.Context, in ArchiveItemInput) error {
    // ... archive logic
    
    // Check if quantity is low after archiving
    if item.Quantity <= 5 && item.Quantity > 0 {
        uc.notifications.SendLowStockAlert(ctx, item)
    }
    
    return nil
}
```

**Notification**:
```json
{
  "aps": {
    "alert": {
      "title": "Low Stock Alert",
      "body": "Only 3 units of Coca-Cola 0.5L remaining"
    },
    "sound": "default"
  },
  "item_id": "uuid",
  "type": "low_stock"
}
```

### 3. Team Updates

**Trigger**: When item is created/updated/archived

```go
func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
    item, err := uc.repo.Create(ctx, in)
    if err != nil {
        return nil, err
    }
    
    // Notify team members
    uc.notifications.SendTeamUpdate(ctx, domain.NotificationTeamUpdate{
        OrganizationID: item.OrganizationID,
        Title:          "New Item Added",
        Body:           fmt.Sprintf("%s added %s", userName, item.Name),
        ItemID:         item.ID,
        Type:           "item_created",
    })
    
    return item, nil
}
```

### 4. Event Reminders

**Trigger**: 24 hours before event starts

```go
func (uc *NotificationsUseCase) SendEventReminders(ctx context.Context) error {
    // Find events starting in 24 hours
    events, err := uc.eventRepo.FindUpcoming(ctx, 24*time.Hour)
    if err != nil {
        return err
    }
    
    for _, event := range events {
        notification := &apns2.Notification{
            Payload: map[string]interface{}{
                "aps": map[string]interface{}{
                    "alert": map[string]interface{}{
                        "title": "Event Tomorrow",
                        "body":  fmt.Sprintf("%s starts tomorrow", event.Name),
                    },
                },
                "event_id": event.ID.String(),
                "type":     "event_reminder",
            },
        }
        
        // Send to organization members
        uc.sendToOrganization(ctx, event.OrganizationID, notification)
    }
    
    return nil
}
```

## Notification Types

| Type | Trigger | Priority | Sound |
|------|---------|----------|-------|
| `expiration_warning` | 3 days before expiry | High | default |
| `expiration_critical` | 1 day before expiry | Critical | alarm |
| `low_stock` | Quantity ≤ 5 | Medium | default |
| `out_of_stock` | Quantity = 0 | High | default |
| `item_created` | New item added | Low | none |
| `item_updated` | Item modified | Low | none |
| `item_archived` | Item archived | Low | none |
| `event_reminder` | 24h before event | Medium | default |

## User Preferences

### Database Schema

```sql
CREATE TABLE notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    expiration_warnings BOOLEAN DEFAULT TRUE,
    low_stock_alerts BOOLEAN DEFAULT TRUE,
    team_updates BOOLEAN DEFAULT TRUE,
    event_reminders BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Settings UI

```swift
struct NotificationSettingsView: View {
    @State var expirationWarnings = true
    @State var lowStockAlerts = true
    @State var teamUpdates = false
    @State var eventReminders = true
    
    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Expiration Warnings", isOn: $expirationWarnings)
                Toggle("Low Stock Alerts", isOn: $lowStockAlerts)
            }
            
            Section("Team") {
                Toggle("Team Updates", isOn: $teamUpdates)
                Toggle("Event Reminders", isOn: $eventReminders)
            }
        }
    }
}
```

## Cron Jobs

### Setup

```bash
# /etc/crontab or systemd timer

# Send expiration warnings daily at 9 AM
0 9 * * * /usr/bin/warehouse-notifications expiration-warnings

# Send event reminders daily at 8 AM
0 8 * * * /usr/bin/warehouse-notifications event-reminders

# Check low stock every hour
0 * * * * /usr/bin/warehouse-notifications low-stock-check
```

### CLI Command

```go
// cmd/notifications/main.go

func main() {
    if len(os.Args) < 2 {
        log.Fatal("Usage: warehouse-notifications <command>")
    }
    
    command := os.Args[1]
    
    switch command {
    case "expiration-warnings":
        sendExpirationWarnings()
    case "event-reminders":
        sendEventReminders()
    case "low-stock-check":
        checkLowStock()
    default:
        log.Fatalf("Unknown command: %s", command)
    }
}
```

## iOS Handling

### AppDelegate

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse,
                           withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    guard let type = userInfo["type"] as? String else {
        completionHandler()
        return
    }
    
    switch type {
    case "expiration_warning", "expiration_critical":
        if let itemID = userInfo["item_id"] as? String {
            navigateToItem(UUID(uuidString: itemID))
        }
    case "low_stock", "out_of_stock":
        if let itemID = userInfo["item_id"] as? String {
            navigateToItem(UUID(uuidString: itemID))
        }
    case "event_reminder":
        if let eventID = userInfo["event_id"] as? String {
            navigateToEvent(UUID(uuidString: eventID))
        }
    default:
        break
    }
    
    completionHandler()
}
```

## Testing

### Send Test Notification

```bash
curl -X POST http://localhost:8080/admin/notifications/test \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "uuid",
    "type": "expiration_warning",
    "title": "Test Notification",
    "body": "This is a test"
  }'
```

## Monitoring

### Metrics to Track

1. **Delivery Rate**: % of notifications successfully delivered
2. **Open Rate**: % of notifications opened by users
3. **Opt-out Rate**: % of users disabling notifications
4. **Error Rate**: % of failed notification sends

### Logging

```go
log.Info("notification sent",
    "type", notificationType,
    "user_id", userID,
    "item_id", itemID,
    "success", success,
)
```

## Best Practices

1. **Respect User Preferences** - Check settings before sending
2. **Batch Notifications** - Group similar notifications
3. **Rate Limiting** - Don't spam users
4. **Localization** - Send in user's language
5. **Deep Linking** - Navigate to relevant screen

## Future Enhancements

1. **Rich Notifications** - Images, actions
2. **Notification History** - View past notifications
3. **Smart Scheduling** - Send at optimal times
4. **A/B Testing** - Test notification copy
5. **Analytics Dashboard** - Track notification performance

## Resources

- [APNs Documentation](https://developer.apple.com/documentation/usernotifications)
- [Push Notification Best Practices](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
