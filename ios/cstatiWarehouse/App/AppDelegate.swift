//
//  AppDelegate.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        RemotePushRegistration.submitDeviceTokenHex(hex)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        _ = error
    }
}
