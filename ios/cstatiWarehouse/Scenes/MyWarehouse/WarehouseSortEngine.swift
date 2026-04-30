//
//  WarehouseSortEngine.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

final class WarehouseSortEngine {
    
    func sort(_ items: [Item], by option: WarehouseSortOption) -> [Item] {
        switch option {
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .quantityAsc:
            return items.sorted { $0.effectiveQuantityForSort < $1.effectiveQuantityForSort }
        case .quantityDesc:
            return items.sorted { $0.effectiveQuantityForSort > $1.effectiveQuantityForSort }
        case .expirationAsc:
            return sortByExpiryDate(items, ascending: true)
        case .nameAsc:
            return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }
    
    // MARK: - Private Helpers
    
    private func sortByExpiryDate(_ items: [Item], ascending: Bool) -> [Item] {
        items.sorted { lhs, rhs in
            let lhsDate = earliestExpiryDate(for: lhs)
            let rhsDate = earliestExpiryDate(for: rhs)
            
            switch (lhsDate, rhsDate) {
            case (nil, nil):
                return false
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case let (.some(l), .some(r)):
                return ascending ? l < r : l > r
            }
        }
    }
    
    private func earliestExpiryDate(for item: Item) -> Date? {
        if !item.variants.isEmpty {
            return item.variants.compactMap { $0.expirationDate }.min()
        }
        return item.expirationDate
    }
}
