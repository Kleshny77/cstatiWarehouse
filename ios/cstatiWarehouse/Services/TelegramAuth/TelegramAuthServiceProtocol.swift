//
//  TelegramAuthServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

struct TelegramAuthResult {
    let idToken: String
}

enum TelegramAuthError: Error {
    case notConfigured
    case cancelled
    case underlying(Error)
    
    var message: String {
        switch self {
        case .notConfigured:
            return "Telegram Login не настроен. Проверьте TelegramAuthConfig."
        case .cancelled:
            return "Вход через Telegram отменён"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

protocol TelegramAuthServiceProtocol: AnyObject {
    func signIn(completion: @escaping (Result<TelegramAuthResult, TelegramAuthError>) -> Void)
}
