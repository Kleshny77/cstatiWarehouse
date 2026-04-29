//
//  WarehouseSortEngine.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

/// Движок сортировки позиций склада.
/// Инкапсулирует всю логику сортировки списка позиций.
final class WarehouseSortEngine {
    
    /// Сортирует список позиций согласно выбранной опции.
    /// - Parameters:
    ///   - items: Исходный список позиций
    ///   - option: Опция сортировки
    /// - Returns: Отсортированный список позиций
    func sort(_ items: [Item], by option: WarehouseSortOption) -> [Item] {
        switch option {
        case .nameAsc:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .nameDesc:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            
        case .quantityAsc:
            return items.sorted { $0.effectiveQuantityForSort < $1.effectiveQuantityForSort }
            
        case .quantityDesc:
            return items.sorted { $0.effectiveQuantityForSort > $1.effectiveQuantityForSort }
            
        case .expiryDateAsc:
            return sortByExpiryDate(items, ascending: true)
            
        case .expiryDateDesc:
            return sortByExpiryDate(items, ascending: false)
            
        case .createdAtDesc:
            return items.sorted { $0.createdAt > $1.createdAt }
            
        case .updatedAtDesc:
            return items.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
    
    // MARK: - Private Helpers
    
    private func sortByExpiryDate(_ items: [Item], ascending: Bool) -> [Item] {
        items.sorted { lhs, rhs in
            let lhsDate = earliestExpiryDate(for: lhs)
            let rhsDate = earliestExpiryDate(for: rhs)
            
            // Позиции без срока годности идут в конец
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
        // Для родительских позиций проверяем варианты
        if !item.variants.isEmpty {
            return item.variants.compactMap { $0.expirationDate }.min()
        }
        return item.expirationDate
    }
}
