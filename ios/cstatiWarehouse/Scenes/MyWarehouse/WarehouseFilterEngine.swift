//
//  WarehouseFilterEngine.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

final class WarehouseFilterEngine {

    func apply(filters: WarehouseFilters, to items: [Item]) -> [Item] {
        var result = items
        if !filters.selectedCategories.isEmpty {
            result = result.filter { item in
                categoryMatchesFilter(selected: filters.selectedCategories, itemCategory: item.categoryName)
            }
        }
        if !filters.expirationSet.isEmpty {
            result = result.filter { item in
                let status = item.expirationStatusConsideringVariants()
                return filters.expirationSet.contains { $0.matches(status) }
            }
        }
        if !filters.smartFilters.isEmpty {
            result = result.filter { item in
                filters.smartFilters.allSatisfy { $0.matches(item) }
            }
        }
        return result
    }

    private func categoryMatchesFilter(selected: Set<String>, itemCategory: String) -> Bool {
        let itemKey = itemCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemKey.isEmpty else { return false }
        let locale = Locale(identifier: "ru_RU")
        return selected.contains { raw in
            let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return false }
            return candidate.compare(itemKey, options: [.caseInsensitive], locale: locale) == .orderedSame
        }
    }
}
