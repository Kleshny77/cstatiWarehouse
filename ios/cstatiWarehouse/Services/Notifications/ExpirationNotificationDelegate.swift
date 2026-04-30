//
//  ExpirationNotificationDelegate.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import UserNotifications

extension Notification.Name {
    static let expirationNotificationOpenItem = Notification.Name("expirationNotificationOpenItem")
}

enum ExpirationOpenUserInfoKey {
    static let itemID = "item_id"
    static let organizationID = "organization_id"
}

final class ExpirationNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = ExpirationNotificationDelegate(
        preferencesService: ApiNotificationPreferencesService(apiClient: AppServices.apiClient)
    )

    private let preferencesService: NotificationPreferencesServiceProtocol

    init(preferencesService: NotificationPreferencesServiceProtocol) {
        self.preferencesService = preferencesService
        super.init()
    }

    // MARK: - Foreground presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    // MARK: - Action handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let itemIDString = userInfo[ExpirationNotificationActions.UserInfoKey.itemID] as? String,
              let itemID = UUID(uuidString: itemIDString) else {
            return
        }
        let orgIDString = userInfo[ExpirationNotificationActions.UserInfoKey.organizationID] as? String
        let organizationID = orgIDString.flatMap(UUID.init(uuidString:))

        switch response.actionIdentifier {
        case ExpirationNotificationActions.ActionIdentifier.snooze1Hour:
            performSnooze(itemID: itemID, duration: 60 * 60)

        case ExpirationNotificationActions.ActionIdentifier.snooze1Day:
            performSnooze(itemID: itemID, duration: 24 * 60 * 60)

        case ExpirationNotificationActions.ActionIdentifier.markUsed,
             ExpirationNotificationActions.ActionIdentifier.view,
             UNNotificationDefaultActionIdentifier:
            postOpenItem(itemID: itemID, organizationID: organizationID)

        case UNNotificationDismissActionIdentifier:
            break

        default:
            break
        }
    }

    // MARK: - Helpers

    private func performSnooze(itemID: UUID, duration: TimeInterval) {
        preferencesService.snooze(itemID: itemID, duration: duration) { _ in
        }
    }

    private func postOpenItem(itemID: UUID, organizationID: UUID?) {
        var info: [String: Any] = [ExpirationOpenUserInfoKey.itemID: itemID]
        if let orgID = organizationID {
            info[ExpirationOpenUserInfoKey.organizationID] = orgID
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .expirationNotificationOpenItem,
                object: nil,
                userInfo: info
            )
        }
    }
}
