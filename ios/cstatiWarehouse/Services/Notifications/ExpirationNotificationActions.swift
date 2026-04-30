//
//  ExpirationNotificationActions.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import UserNotifications

enum ExpirationNotificationActions {

    static let categoryIdentifier = "EXPIRATION_ACTION"

    enum ActionIdentifier {
        static let markUsed = "expiration.mark_used"
        static let snooze1Hour = "expiration.snooze_1h"
        static let snooze1Day = "expiration.snooze_1d"
        static let view = "expiration.view"
    }

    enum UserInfoKey {
        static let itemID = "item_id"
        static let organizationID = "organization_id"
        static let level = "level"
    }

    static func register(in center: UNUserNotificationCenter = .current()) {
        let markUsed = UNNotificationAction(
            identifier: ActionIdentifier.markUsed,
            title: "Использовать сейчас",
            options: [.authenticationRequired, .foreground]
        )
        let snooze1H = UNNotificationAction(
            identifier: ActionIdentifier.snooze1Hour,
            title: "Напомнить через час",
            options: []
        )
        let snooze1D = UNNotificationAction(
            identifier: ActionIdentifier.snooze1Day,
            title: "Напомнить завтра",
            options: []
        )
        let view = UNNotificationAction(
            identifier: ActionIdentifier.view,
            title: "Открыть",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [markUsed, snooze1H, snooze1D, view],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }
}
