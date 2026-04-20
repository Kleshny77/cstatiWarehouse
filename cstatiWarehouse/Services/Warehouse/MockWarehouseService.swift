//
// MockWarehouseService.swift
// cstatiWarehouse
//
// Created by Артём on 19.04.2026.
//

import Foundation

final class MockWarehouseService: WarehouseServiceProtocol {
    static let shared = MockWarehouseService()

    /// Каждая позиция хранится в привязке к organizationID, чтобы мок честно реагировал
    /// на переключение активной организации.
    private var items: [UUID: (orgID: UUID, item: Item)] = [:]
    private var events: [(orgID: UUID, event: ArchiveEvent)] = []

    init(seed: [Item] = MockWarehouseService.defaultSeed()) {
        let defaultOrg = UUID()
        for item in seed {
            items[item.id] = (defaultOrg, item)
        }
    }

    // MARK: Public Methods

    func fetchActiveItems(organizationID: UUID, completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        respond {
            let active = self.items.values
                .filter { $0.orgID == organizationID && !$0.item.status.isArchived }
                .map(\.item)
            completion(.success(active.sorted { $0.createdAt > $1.createdAt }))
        }
    }

    func fetchHistory(organizationID: UUID, completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        respond {
            let history = self.items.values
                .filter { $0.orgID == organizationID && $0.item.status.isArchived }
                .map(\.item)
            let sorted = history.sorted { lhs, rhs in
                guard case let .archived(_, lDate) = lhs.status,
                      case let .archived(_, rDate) = rhs.status else { return false }
                return lDate > rDate
            }
            completion(.success(sorted))
        }
    }

    func fetchArchiveEvents(organizationID: UUID, completion: @escaping (Result<[ArchiveEvent], WarehouseError>) -> Void) {
        respond {
            let filtered = self.events
                .filter { $0.orgID == organizationID }
                .map(\.event)
                .sorted { $0.archivedAt > $1.archivedAt }
            completion(.success(filtered))
        }
    }

    func fetchCategories(organizationID: UUID, completion: @escaping (Result<[String], WarehouseError>) -> Void) {
        respond {
            let active = self.items.values
                .filter { $0.orgID == organizationID && !$0.item.status.isArchived }
                .map(\.item)
            let names = Set(active.map(\.categoryName))
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            completion(.success(names.sorted { $0.localizedCompare($1) == .orderedAscending }))
        }
    }

    func createItem(_ item: Item, organizationID: UUID, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        respond {
            self.items[item.id] = (organizationID, item)
            completion(.success(item))
        }
    }

    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        respond {
            guard let existing = self.items[item.id] else {
                completion(.failure(.notFound))
                return
            }
            self.items[item.id] = (existing.orgID, item)
            completion(.success(item))
        }
    }

    func archiveItem(
        id: UUID,
        quantity: Int,
        reason: ArchiveReason,
        reasonDetail: String,
        completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
    ) {
        respond {
            guard let existing = self.items[id] else {
                completion(.failure(.notFound))
                return
            }
            var item = existing.item
            guard quantity > 0 else {
                completion(.failure(.validationError("Укажите количество больше 0")))
                return
            }
            guard quantity <= item.quantity else {
                completion(.failure(.validationError("Недостаточно единиц на складе")))
                return
            }
            if reason.requiresDetail,
               reasonDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                completion(.failure(.validationError("Укажите подробности")))
                return
            }

            let now = Date.now
            item.quantity -= quantity
            if item.quantity == 0 {
                item.status = .archived(reason: reason, at: now)
            }
            self.items[id] = (existing.orgID, item)

            let event = ArchiveEvent(
                id: UUID(),
                itemID: id,
                quantity: quantity,
                reason: reason,
                reasonDetail: reasonDetail,
                archivedAt: now
            )
            self.events.append((existing.orgID, event))

            completion(.success(ArchiveResult(item: item, event: event)))
        }
    }

    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void) {
        respond {
            guard self.items.removeValue(forKey: id) != nil else {
                completion(.failure(.notFound))
                return
            }
            self.events.removeAll { $0.event.itemID == id }
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
