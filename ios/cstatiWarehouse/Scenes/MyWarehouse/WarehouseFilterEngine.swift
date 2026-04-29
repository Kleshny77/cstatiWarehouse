//
//  WarehouseFilterEngine.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

/// Движок фильтрации позиций склада.
/// Инкапсулирует всю логику применения фильтров к списку позиций.
final class WarehouseFilterEngine {
    
    /// Применяет фильтры к списку позиций.
    /// - Parameters:
    ///   - items: Исходный список позиций
    ///   - filters: Активные фильтры
    ///   - availableCategories: Доступные категории для проверки
    /// - Returns: Отфильтрованный список позиций
    func apply(
        filters: WarehouseFilters,
        to items: [Item],
        availableCategories: [String]
    ) -> [Item] {
        var result = items
        
        // Фильтр по категориям
        if !filters.selectedCategories.isEmpty {
            result = result.filter { item in
                categoryMatches(selected: filters.selectedCategories, itemCategory: item.categoryName)
            }
        }
        
        // Фильтр по держателю
        if let holderID = filters.holderUserID {
            result = result.filter { $0.heldByUserID == holderID }
        }
        
        // Фильтр по статусу срока годности
        if let expiryFilter = filters.expirationStatus {
            result = result.filter { item in
                matchesExpirationFilter(item: item, filter: expiryFilter)
            }
        }
        
        // Фильтр "Только заканчивающиеся"
        if filters.onlyLowStock {
            result = result.filter { item in
                isLowStock(item: item)
            }
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func categoryMatches(selected: Set<String>, itemCategory: String) -> Bool {
        selected.contains(itemCategory)
    }
    
    private func matchesExpirationFilter(item: Item, filter: ExpirationStatus) -> Bool {
        let status = item.expirationStatusConsideringVariants()
        switch filter {
        case .expired:
            if case .expired = status { return true }
            return false
        case .expiringSoon:
            if case .expiringSoon = status { return true }
            return false
        case .ok:
            if case .ok = status { return true }
            return false
        case .none:
            if case .none = status { return true }
            return false
        }
    }
    
    private func isLowStock(item: Item) -> Bool {
        // Считаем "заканчивающимся" если количество <= 2
        // Для родительских позиций проверяем суммарное количество вариантов
        if item.variants.isEmpty {
            return item.quantity <= 2
        } else {
            let totalVariants = item.variants.reduce(0) { $0 + $1.quantity }
            return totalVariants <= 2
        }
    }
}
