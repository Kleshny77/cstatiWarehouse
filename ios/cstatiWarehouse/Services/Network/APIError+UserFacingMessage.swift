//
//  APIError+UserFacingMessage.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

extension APIError {

    /// Сообщение для диалогов и пассивных уведомлений (на русском).
    var userFacingMessage: String {
        switch self {
        case .transport(let underlying):
            return Self.messageForTransportError(underlying)
        case .decoding:
            return "Не удалось разобрать ответ сервера. Попробуйте ещё раз."
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        case .server(_, _, let message, _):
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            return "Сервер вернул ошибку. Попробуйте позже."
        }
    }

    private static func messageForTransportError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
                return "Нет подключения к интернету."
            case NSURLErrorTimedOut:
                return "Превышено время ожидания. Проверьте сеть и попробуйте снова."
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "Не удалось найти сервер. Проверьте адрес API в настройках."
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                return "Не удалось связаться с сервером. Проверьте сеть."
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
                return "Ошибка защищённого соединения (TLS)."
            default:
                break
            }
        }
        return "Ошибка сети. Проверьте подключение."
    }
}
