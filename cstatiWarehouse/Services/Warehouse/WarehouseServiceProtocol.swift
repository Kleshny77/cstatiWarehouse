//
// WarehouseServiceProtocol.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

enum WarehouseError: Error {
    case notFound
    case validationError(String)
    case networkError(Error?)
    case serverError(String)
    case unauthorized

    var message: String {
        switch self {
        case .notFound:
            return "Позиция не найдена"
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

protocol WarehouseServiceProtocol: AnyObject {
    func fetchActiveItems(completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func fetchHistory(completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func fetchArchiveEvents(completion: @escaping (Result<[ArchiveEvent], WarehouseError>) -> Void)
    func fetchCategories(completion: @escaping (Result<[String], WarehouseError>) -> Void)
    func createItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func archiveItem(
        id: UUID,
        quantity: Int,
        reason: ArchiveReason,
        reasonDetail: String,
        completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
    )
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void)
}
