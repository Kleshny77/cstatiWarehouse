//
//  ActivityServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

enum ActivityError: Error {
    case forbidden
    case notFound
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .forbidden: return "Недостаточно прав"
        case .notFound: return "Организация не найдена"
        case .networkError: return "Ошибка сети. Проверьте подключение."
        case .serverError(let text): return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized: return "Сессия истекла. Войдите заново."
        }
    }
}

protocol ActivityServiceProtocol: AnyObject {
    func list(organizationID: UUID, limit: Int?, completion: @escaping (Result<[ActivityEntry], ActivityError>) -> Void)
}
