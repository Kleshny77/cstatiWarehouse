//
//  EventsServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

enum EventsError: Error {
    case notFound
    case forbidden
    case validationError(String)
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .notFound: return "Мероприятие не найдено"
        case .forbidden: return "Недостаточно прав"
        case .validationError(let text): return text
        case .networkError: return "Ошибка сети. Проверьте подключение."
        case .serverError(let text): return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized: return "Сессия истекла. Войдите заново."
        }
    }
}

protocol EventsServiceProtocol: AnyObject {
    func list(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void)
    func create(organizationID: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void)
    func update(id: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, EventsError>) -> Void)
}
