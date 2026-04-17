//
//  MockWarehouseService.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

final class MockWarehouseService: WarehouseServiceProtocol {
    static let shared = MockWarehouseService()
    
    private var items: [UUID: Item] = [:]
    
    init(seed: [Item] = MockWarehouseService.defaultSeed()) {
        for item in seed {
            items[item.id] = item
        }
    }
    
    // MARK: Public Methods
    
    func fetchActiveItems(completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        respond {
            let active = self.items.values.filter { !$0.status.isArchived }
            completion(.success(active.sorted { $0.createdAt > $1.createdAt }))
        }
    }
    
    func fetchHistory(completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        respond {
            let history = self.items.values.filter { $0.status.isArchived }
            let sorted = history.sorted { lhs, rhs in
                guard case let .archived(_, lDate) = lhs.status,
                      case let .archived(_, rDate) = rhs.status else { return false }
                return lDate > rDate
            }
            completion(.success(sorted))
        }
    }
    
    func createItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        respond {
            self.items[item.id] = item
            completion(.success(item))
        }
    }
    
    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        respond {
            guard self.items[item.id] != nil else {
                completion(.failure(.notFound))
                return
            }
            self.items[item.id] = item
            completion(.success(item))
        }
    }
    
    func archiveItem(id: UUID, reason: ArchiveReason, at date: Date, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        respond {
            guard var item = self.items[id] else {
                completion(.failure(.notFound))
                return
            }
            item.status = .archived(reason: reason, at: date)
            self.items[id] = item
            completion(.success(item))
        }
    }
    
    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void) {
        respond {
            guard self.items.removeValue(forKey: id) != nil else {
                completion(.failure(.notFound))
                return
            }
            completion(.success(()))
        }
    }
    
    // MARK: Private Methods
    
    private func respond(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
    
    private static func defaultSeed() -> [Item] {
        let now = Date.now
        let cal = Calendar.current
        return [
            Item(
                name: "водка я ротбб",
                description: "русский стандарт 0,5 открытая большая",
                categoryName: "еда",
                quantity: 8,
                expirationDate: nil,
                createdAt: cal.date(byAdding: .day, value: -10, to: now) ?? now
            ),
            Item(
                name: "креветки",
                categoryName: "еда",
                quantity: 3,
                expirationDate: cal.date(byAdding: .day, value: -5, to: now),
                createdAt: cal.date(byAdding: .day, value: -9, to: now) ?? now
            ),
            Item(
                name: "пиво",
                categoryName: "напитки",
                quantity: 12,
                expirationDate: cal.date(byAdding: .day, value: 7, to: now),
                createdAt: cal.date(byAdding: .day, value: -8, to: now) ?? now
            ),
            Item(
                name: "лимонад",
                categoryName: "напитки",
                quantity: 6,
                expirationDate: cal.date(byAdding: .day, value: 25, to: now),
                createdAt: cal.date(byAdding: .day, value: -7, to: now) ?? now
            ),
            Item(
                name: "капибара",
                categoryName: "напитки",
                quantity: 1,
                expirationDate: cal.date(byAdding: .day, value: 45, to: now),
                createdAt: cal.date(byAdding: .day, value: -6, to: now) ?? now
            ),
            Item(
                name: "водка",
                categoryName: "напитки",
                quantity: 2,
                expirationDate: cal.date(byAdding: .day, value: 120, to: now),
                createdAt: cal.date(byAdding: .day, value: -5, to: now) ?? now
            )
        ]
    }
}
