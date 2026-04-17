//
//  WarehouseServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

enum WarehouseError: Error {
    case notFound
    case networkError(Error?)
    case serverError(String)
    
    var message: String {
        switch self {
        case .notFound:
            return "Позиция не найдена"
        case .networkError:
            return "Ошибка сети. Проверьте подключение."
        case .serverError(let text):
            return text.isEmpty ? "Ошибка сервера" : text
        }
    }
}

protocol WarehouseServiceProtocol: AnyObject {
    func fetchActiveItems(completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func fetchHistory(completion: @escaping (Result<[Item], WarehouseError>) -> Void)
    func createItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func archiveItem(id: UUID, reason: ArchiveReason, at date: Date, completion: @escaping (Result<Item, WarehouseError>) -> Void)
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void)
}
