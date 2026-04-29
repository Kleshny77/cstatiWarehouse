//
// WarehouseServiceProtocol.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

enum WarehouseError: Error {
    case notFound
    case forbidden
    case validationError(String)
    case networkError(Error?)
    case serverError(String)
    case unauthorized
    /// Сервер отклонил сохранение: позиция уже изменена; в теле ответа пришла актуальная версия.
    case concurrentModification(Item)

    var message: String {
        switch self {
        case .notFound:
            return "Позиция не найдена"
        case .forbidden:
            return "Недостаточно прав"
        case .validationError(let text):
            return text
        case .networkError:
            return "Ошибка сети. Проверьте подключение."
        case .serverError(let text):
            return text.isEmpty ? "Ошибка сервера" : text
        case .unauthorized:
            return "Сессия истекла. Войдите заново."
        case .concurrentModification:
            return "Позиция уже изменена на сервере или с другого устройства. Форма обновлена — проверьте данные и сохраните снова."
        }
    }
}

struct ArchiveResult {
    let item: Item
    let event: ArchiveEvent
}

enum WarehouseScope: String {
    case mine
    case all
}

protocol WarehouseServiceProtocol: AnyObject {
    func fetchActiveItems(organizationID: UUID, scope: WarehouseScope, completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func fetchHistory(organizationID: UUID, completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func fetchArchiveEvents(organizationID: UUID, completion: @escaping (Result<[ArchiveEvent], WarehouseError>) -> Void)
    func fetchCategories(organizationID: UUID, completion: @escaping (Result<[String], WarehouseError>) -> Void)
    func createItem(_ item: Item, organizationID: UUID, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func archiveItem(
        id: UUID,
        quantity: Int,
        reason: ArchiveReason,
        reasonDetail: String,
        eventID: UUID?,
        expectedUpdatedAt: Date,
        completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
    )
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void)
}
