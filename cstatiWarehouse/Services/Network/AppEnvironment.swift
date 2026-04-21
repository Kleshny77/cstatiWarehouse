//
//  AppEnvironment.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// Конфигурация окружения клиента.
enum AppEnvironment {
    /// Ключ в `Info.plist`: непустая строка переопределяет URL (удобно для LAN без пересборки кода из другой ветки).
    private static let backendBaseURLPlistKey = "BackendBaseURL"

    /// Базовый URL бэкенда.
    ///
    /// - Опционально: задайте `BackendBaseURL` в Info.plist, например `http://192.168.0.12:8080`.
    /// - Симулятор: `http://localhost:8080` (тот же хост, что и Docker на Mac; совпадает с ATS `localhost`).
    /// - Устройство без ключа: пример LAN ниже — **замените на IP вашего Mac** (`ifconfig` / «Системные настройки»).
    static let backendBaseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: backendBaseURLPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }
        #if targetEnvironment(simulator)
        let string = "http://localhost:8080"
        #else
        let string = "http://192.168.1.65:8080"
        #endif
        guard let url = URL(string: string) else {
            fatalError("Invalid backend base URL")
        }
        return url
    }()
}
