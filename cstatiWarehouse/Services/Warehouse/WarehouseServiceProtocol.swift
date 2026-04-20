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
        }
    }
}

/// Результат списания: обновлённая позиция и созданная запись об утилизации.
struct ArchiveResult {
    let item: Item
    let event: ArchiveEvent
}

/// Скоуп выдачи активных позиций в списке склада.
/// `mine` — только позиции, за которые отвечает текущий пользователь.
/// `all` — все позиции организации (доступно только админу/владельцу, бэкенд молча фильтрует обратно к `mine`, если прав нет).
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
        completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
    )
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void)
}
