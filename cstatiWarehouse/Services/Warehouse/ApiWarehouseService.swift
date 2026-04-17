//
//  ApiWarehouseService.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

/// Подключить когда бекенд на Go будет готов.
/// baseURL + URLSession запросы к REST-эндпоинтам склада.
/// Ответы маппить в Item, ошибки — в WarehouseError.
final class ApiWarehouseService: WarehouseServiceProtocol {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL = URL(string: "https://api.example.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func fetchActiveItems(completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        // TODO: GET baseURL/warehouse/items?status=in_stock
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
    
    func fetchHistory(completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        // TODO: GET baseURL/warehouse/items?status=archived
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
    
    func createItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        // TODO: POST baseURL/warehouse/items
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
    
    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        // TODO: PATCH baseURL/warehouse/items/{id}
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
    
    func archiveItem(id: UUID, reason: ArchiveReason, at date: Date, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        // TODO: POST baseURL/warehouse/items/{id}/archive, body: { reason, at }
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
    
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void) {
        // TODO: DELETE baseURL/warehouse/items/{id}
        completion(.failure(.serverError("Бекенд ещё не подключён")))
    }
}
