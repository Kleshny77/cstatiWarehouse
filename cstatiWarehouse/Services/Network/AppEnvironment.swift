//
//  AppEnvironment.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// Конфигурация окружения клиента. Сейчас baseURL захардкожен —
/// при деплое можно читать из Info.plist или build-configuration.
enum AppEnvironment {
    /// Базовый URL бэкенда.
    ///
    /// - Симулятор: `http://localhost:8080` работает, т.к. симулятор разделяет сеть с хостом.
    /// - Физическое устройство в той же Wi-Fi-сети: замените на LAN-IP, например `http://192.168.1.42:8080`.
    /// - Удалённый сервер: публичный домен с HTTPS.
    static let backendBaseURL: URL = {
        guard let url = URL(string: "http://localhost:8080") else {
            fatalError("Invalid backend base URL")
        }
        return url
    }()
}
