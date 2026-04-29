//
//  RemotePushRegistration.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import UIKit

/// Регистрация APNs device token на backend (`POST /notifications/apns-token`).
/// Локальные напоминания о сроках годности работают без этого; удалённые пуши требуют возможности Push в Xcode и учётной записи разработчика Apple.
enum RemotePushRegistration {

    static func registerForRemoteNotificationsIfPossible() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    static func submitDeviceTokenHex(_ hex: String) {
        struct Body: Encodable {
            let token: String
        }
        AppServices.apiClient.requestVoid(
            path: "/notifications/apns-token",
            method: .post,
            body: Body(token: hex),
            authenticated: true
        ) { _ in }
    }
}
