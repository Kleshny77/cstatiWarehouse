//
//  OrgCategoriesServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

enum OrgCategoriesError: Error {
    case notFound
    case forbidden
    case conflict(String)
    case validationError(String)
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .notFound: return "Категория не найдена"
        case .forbidden: return "Недостаточно прав"
        case .conflict(let text): return text.isEmpty ? "Категория с таким названием уже существует" : text
        case .validationError(let text): return text
        case .networkError: return "Ошибка сети. Проверьте подключение."
        case .serverError(let text): return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized: return "Сессия истекла. Войдите заново."
        }
    }
}

protocol OrgCategoriesServiceProtocol: AnyObject {
    func list(organizationID: UUID, completion: @escaping (Result<[OrgCategory], OrgCategoriesError>) -> Void)
    func create(organizationID: UUID, name: String, completion: @escaping (Result<OrgCategory, OrgCategoriesError>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, OrgCategoriesError>) -> Void)
}
