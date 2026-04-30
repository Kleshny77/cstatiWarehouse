//
//  SmartExpirationScheduler.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import UserNotifications

protocol SmartExpirationSchedulerProtocol: AnyObject {
    func synchronize(organizationID: UUID, organizationName: String, items: [Item], preferences: NotificationPreferences)
}

final class SmartExpirationScheduler: SmartExpirationSchedulerProtocol {

    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let fireHour: Int
    private let fireMinute: Int
    private let identifierPrefix = "cstatiWarehouse.smartExpiration"

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        fireHour: Int = 9,
        fireMinute: Int = 0
    ) {
        self.center = center
        self.calendar = calendar
        self.fireHour = fireHour
        self.fireMinute = fireMinute
    }

    func synchronize(
        organizationID: UUID,
        organizationName: String,
        items: [Item],
        preferences: NotificationPreferences
    ) {
        let activeItems = items.filter { !$0.status.isArchived && $0.expirationDate != nil }
        let activeIDs = Set(items.filter { !$0.status.isArchived }.map(\.id))

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let stale = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.identifierPrefix) }
                .filter { id in
                    guard let parsed = self.parseIdentifier(id) else { return true }
                    return !activeIDs.contains(parsed.itemID)
                }
            if !stale.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: stale)
            }

            self.requestAuthorizationIfNeeded { granted in
                guard granted else { return }
                ExpirationNotificationActions.register(in: self.center)

                for item in activeItems {
                    self.scheduleAllLevels(
                        item: item,
                        organizationID: organizationID,
                        organizationName: organizationName,
                        preferences: preferences
                    )
                }
            }
        }
    }

    // MARK: - Authorization

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - Scheduling

    private func scheduleAllLevels(
        item: Item,
        organizationID: UUID,
        organizationName: String,
        preferences: NotificationPreferences
    ) {
        guard let expiration = item.expirationDate else { return }

        for level in ExpirationLevel.allCases where preferences.isEnabled(level) {
            let id = makeIdentifier(itemID: item.id, level: level)
            center.removePendingNotificationRequests(withIdentifiers: [id])

            guard let fireDate = computeFireDate(forExpiration: expiration, level: level),
                  fireDate > Date() else {
                continue
            }

            let content = makeContent(
                item: item,
                organizationID: organizationID,
                organizationName: organizationName,
                level: level,
                expiration: expiration
            )
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    private func computeFireDate(forExpiration expiration: Date, level: ExpirationLevel) -> Date? {
        let startOfExpiry = calendar.startOfDay(for: expiration)
        let daysOffset = -level.thresholdDays
        guard let day = calendar.date(byAdding: .day, value: daysOffset, to: startOfExpiry) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = fireHour
        components.minute = fireMinute
        return calendar.date(from: components)
    }

    private func makeContent(
        item: Item,
        organizationID: UUID,
        organizationName: String,
        level: ExpirationLevel,
        expiration: Date
    ) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        let formatted = Self.formatDate(expiration)

        switch level {
        case .earlyWarning:
            content.title = "Скоро истекает срок годности"
            content.body = "\(organizationName): «\(item.name)» — через 7 дней (до \(formatted))."
        case .actionRequired:
            content.title = "Срочно: запланируйте использование"
            content.body = "\(organizationName): «\(item.name)» — через 3 дня (до \(formatted))."
        case .critical:
            content.title = "Критично: завтра истекает"
            content.body = "\(organizationName): «\(item.name)» истекает завтра. Используйте сегодня."
        case .expired:
            content.title = "Срок годности истёк"
            content.body = "\(organizationName): «\(item.name)» — срок истёк. Архивируйте позицию."
        }
        content.sound = .default
        content.categoryIdentifier = ExpirationNotificationActions.categoryIdentifier
        if #available(iOS 15.0, *) {
            content.interruptionLevel = level == .critical ? .timeSensitive : .active
        }
        content.userInfo = [
            ExpirationNotificationActions.UserInfoKey.itemID: item.id.uuidString,
            ExpirationNotificationActions.UserInfoKey.organizationID: organizationID.uuidString,
            ExpirationNotificationActions.UserInfoKey.level: level.rawValue,
        ]
        content.threadIdentifier = "expiration.\(organizationID.uuidString)"
        return content
    }

    // MARK: - Identifier helpers

    private func makeIdentifier(itemID: UUID, level: ExpirationLevel) -> String {
        "\(identifierPrefix).\(level.rawValue).\(itemID.uuidString.lowercased())"
    }

    private func parseIdentifier(_ id: String) -> (level: ExpirationLevel, itemID: UUID)? {
        let parts = id.split(separator: ".")
        guard parts.count == 4 else { return nil }
        guard let level = ExpirationLevel(rawValue: String(parts[2])),
              let itemID = UUID(uuidString: String(parts[3])) else { return nil }
        return (level, itemID)
    }

    // MARK: - Formatting

    private static func formatDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ru_RU"))
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
        )
    }
}
