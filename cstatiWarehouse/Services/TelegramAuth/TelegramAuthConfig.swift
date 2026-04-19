//
//  TelegramAuthConfig.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

/// Конфигурация Telegram Login. См. чек-лист в `Docs/TelegramLoginSetup.md`.
/// Пока значения не заполнены, SDK не инициализируется и кнопка «Войти через Telegram»
/// возвращает `notConfigured`.
enum TelegramAuthConfig {

    /// Client ID из @BotFather → Bot Settings → Login Widget.
    static let clientId: String = "8294359177"

    /// Universal Link, который BotFather автоматически зарегистрировал для бота,
    /// например "https://app123456-login.tg.dev". Должен быть добавлен в Associated Domains
    /// с префиксом `applinks:`.
    ///
    /// ВАЖНО: это обязательно **абсолютный URL с https://**, а не clientId.
    /// Пока тут заглушка — реальный URL нужно взять у @BotFather и подставить сюда.
    static let redirectUri: String = ""

    /// Фолбэк custom URL scheme на случай iOS < 17.4 (или если Universal Links недоступны).
    /// Должен совпадать со схемой из Info.plist → URL types. Оставить `nil`, если не нужен.
    static let fallbackScheme: String? = nil

    /// Запрашиваемые OIDC scopes. `openid` добавляется SDK автоматически.
    static let scopes: [String] = ["profile", "phone"]

    /// true, если конфиг заполнен корректно:
    /// - clientId не пустой;
    /// - redirectUri — валидный https:// URL с хостом.
    static var isConfigured: Bool {
        guard !clientId.isEmpty else { return false }
        guard let url = URL(string: redirectUri),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host,
              !host.isEmpty
        else { return false }
        return true
    }
}
