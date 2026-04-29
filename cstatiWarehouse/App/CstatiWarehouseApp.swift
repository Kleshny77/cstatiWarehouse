//
//  CstatiWarehouseApp.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 16.01.2026.
//

import SwiftUI
import TelegramLogin
import UserNotifications

@main
struct CstatiWarehouseApp: App {
    init() {
        // Окно чёрное до первого рендера SwiftUI — убирает белую вспышку при запуске.
        UIWindow.appearance().backgroundColor = .black

        if TelegramAuthConfig.isConfigured {
            TelegramLogin.configure(
                clientId: TelegramAuthConfig.clientId,
                redirectUri: TelegramAuthConfig.redirectUri,
                scopes: TelegramAuthConfig.scopes,
                fallbackScheme: TelegramAuthConfig.fallbackScheme
            )
        }

        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    TelegramLogin.handle(url)
                }
                // Меняет background UIHostingController на тёмный до первого рендера —
                // убирает белую вспышку при запуске приложения.
                .preferredColorScheme(.dark)
        }
    }
}
