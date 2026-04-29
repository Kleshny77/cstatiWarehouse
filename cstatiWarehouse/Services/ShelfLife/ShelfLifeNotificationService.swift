//
//  ShelfLifeNotificationService.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import UserNotifications

protocol ShelfLifeNotificationServiceProtocol: AnyObject {
    /// Планирует локальные уведомления за 30 и за 7 календарных дней до дня окончания срока (в 17:00).
    /// Снимает устаревшие запросы для удалённых/архивных позиций и пересоздаёт при изменении даты.
    /// `organizationID` пока не участвует в идентификаторах (уникальность по `item.id`).
    func synchronize(organizationID: UUID, organizationName: String, items: [Item])
}

/// Показ баннеров, когда приложение на переднем плане.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

final class ShelfLifeNotificationService: ShelfLifeNotificationServiceProtocol {

    // MARK: Properties

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    // MARK: Lifecycle

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    // MARK: Public Methods

    func synchronize(organizationID: UUID, organizationName: String, items: [Item]) {
        let _ = organizationID
        let activeWithShelf = items.filter { !$0.status.isArchived && $0.expirationDate != nil }
        let activeIds = Set(items.filter { !$0.status.isArchived }.map(\.id))

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let stale = requests
                .map(\.identifier)
                .filter { Self.isShelfLifeNotificationId($0) }
                .filter { id in
                    guard let itemId = Self.itemId(fromShelfLifeNotificationId: id) else { return true }
                    return !activeIds.contains(itemId)
                }
            if !stale.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: stale)
            }

            for item in activeWithShelf {
                self.center.removePendingNotificationRequests(withIdentifiers: [
                    Self.notificationId(itemId: item.id, daysBefore: Self.monthDays),
                    Self.notificationId(itemId: item.id, daysBefore: Self.weekDays)
                ])
            }

            self.requestAuthorizationIfNeeded { granted in
                guard granted else { return }
                for item in activeWithShelf {
                    guard let expiration = item.expirationDate else { continue }
                    self.scheduleIfFuture(
                        item: item,
                        organizationName: organizationName,
                        expiration: expiration,
                        daysBefore: Self.monthDays,
                        bodyLead: "через месяц заканчивается срок годности"
                    )
                    self.scheduleIfFuture(
                        item: item,
                        organizationName: organizationName,
                        expiration: expiration,
                        daysBefore: Self.weekDays,
                        bodyLead: "через неделю заканчивается срок годности"
                    )
                }
                #if DEBUG
                self.scheduleHardcodedDebugTest()
                #endif
            }
        }
    }

    // MARK: Private Methods

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func scheduleIfFuture(
        item: Item,
        organizationName: String,
        expiration: Date,
        daysBefore: Int,
        bodyLead: String
    ) {
        let startOfExpiry = calendar.startOfDay(for: expiration)
        guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: startOfExpiry) else {
            return
        }
        var components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
        components.hour = Self.fireHour
        components.minute = Self.fireMinute
        guard let fireDate = calendar.date(from: components) else { return }
        if fireDate <= Date() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Срок годности"
        content.body = "\(organizationName): «\(item.name)» — \(bodyLead) (до \(Self.formatExpiryDate(expiration)))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = Self.notificationId(itemId: item.id, daysBefore: daysBefore)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    #if DEBUG
    /// Временная проверка доставки уведомлений. Удалить перед релизом.
    private func scheduleHardcodedDebugTest() {
        let id = "cstatiWarehouse.debug.shelfLifeTest"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 4
        components.day = 26
        components.hour = 22
        components.minute = 52

        guard let fireDate = calendar.date(from: components), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Тест срока годности (DEBUG)"
        content.body = "Жёстко задано на 26.04.2026 22:52. Убери scheduleHardcodedDebugTest перед релизом."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
    #endif

    private static func formatExpiryDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ru_RU"))
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
        )
    }

    private static func notificationId(itemId: UUID, daysBefore: Int) -> String {
        "cstatiWarehouse.shelfLife.d\(daysBefore).\(itemId.uuidString.lowercased())"
    }

    /// Только `…shelfLife.d7.` / `…shelfLife.d30.` — не пересекается с `…shelfLife.debug…`.
    private static func isShelfLifeNotificationId(_ id: String) -> Bool {
        let prefix = "cstatiWarehouse.shelfLife.d"
        guard id.hasPrefix(prefix) else { return false }
        let afterD = id.dropFirst(prefix.count)
        guard let first = afterD.first, first.isNumber else { return false }
        return true
    }

    private static func itemId(fromShelfLifeNotificationId id: String) -> UUID? {
        guard isShelfLifeNotificationId(id) else { return nil }
        let prefix = "cstatiWarehouse.shelfLife.d"
        let rest = String(id.dropFirst(prefix.count))
        guard let dot = rest.firstIndex(of: ".") else { return nil }
        let uuidString = String(rest[rest.index(after: dot)...])
        return UUID(uuidString: uuidString)
    }

    private static let monthDays = 30
    private static let weekDays = 7
    private static let fireHour = 17
    private static let fireMinute = 0
}

// MARK: - Noop (tests / previews)

final class NoopShelfLifeNotificationService: ShelfLifeNotificationServiceProtocol {
    func synchronize(organizationID: UUID, organizationName: String, items: [Item]) {
        let _ = (organizationID, organizationName, items)
    }
}
