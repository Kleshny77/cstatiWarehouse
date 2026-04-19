//
//  CstatiWarehouseApp.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 16.01.2026.
//

import SwiftUI
import TelegramLogin

@main
struct CstatiWarehouseApp: App {
    init() {
        if TelegramAuthConfig.isConfigured {
            TelegramLogin.configure(
                clientId: TelegramAuthConfig.clientId,
                redirectUri: TelegramAuthConfig.redirectUri,
                scopes: TelegramAuthConfig.scopes,
                fallbackScheme: TelegramAuthConfig.fallbackScheme
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    TelegramLogin.handle(url)
                }
        }
    }
}
