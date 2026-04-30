//
// CstatiWarehouseApp.swift
// cstatiWarehouse
//
// Created by Артём on 26.04.2026.
//

import GoogleSignIn
import SwiftUI
import TelegramLogin
import UserNotifications

@main
struct CstatiWarehouseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UITestConfiguration.prepareIfNeeded()

        UIWindow.appearance().backgroundColor = .black

        Self.configureSharedURLCache()

        if TelegramAuthConfig.isConfigured {
            TelegramLogin.configure(
                clientId: TelegramAuthConfig.clientId,
                redirectUri: TelegramAuthConfig.redirectUri,
                scopes: TelegramAuthConfig.scopes,
                fallbackScheme: TelegramAuthConfig.fallbackScheme
            )
        }

        UNUserNotificationCenter.current().delegate = ExpirationNotificationDelegate.shared
        ExpirationNotificationActions.register()
    }

    private static func configureSharedURLCache() {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 150 * 1024 * 1024
        guard let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        let directory = cachesRoot.appendingPathComponent("cstatiWarehouseURLCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: directory)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                    TelegramLogin.handle(url)
                }
                .preferredColorScheme(.dark)
        }
    }
}
