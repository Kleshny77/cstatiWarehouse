//
//  MyWarehouseEntity.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

struct WarehouseSection: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let items: [Item]
}

struct ItemEditPresentation: Identifiable, Hashable {
    let id = UUID()
    let mode: ItemEditMode
}

enum ItemEditMode: Hashable {
    case create(suggestedCategory: String?)
    case edit(Item)
}

struct ArchivePresentation: Identifiable, Hashable {
    var id: UUID { item.id }
    let item: Item
}

struct DeleteConfirmation: Identifiable, Hashable {
    var id: UUID { item.id }
    let item: Item
}

enum ItemEditResult {
    case saved(Item)
    case cancelled
}

// MARK: - Filters

struct WarehouseFilters: Equatable {
    var selectedCategories: Set<String> = []
    var expirationSet: Set<ExpirationFilter> = []
    var sort: WarehouseSortOption = .newest

    static let none = WarehouseFilters()

    var isActive: Bool {
        !selectedCategories.isEmpty || !expirationSet.isEmpty || sort != .newest
    }
}

enum ExpirationFilter: String, CaseIterable, Identifiable, Hashable {
    case expired
    case expiringSoon
    case fresh
    case noShelfLife

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expired: return "Просрочены"
        case .expiringSoon: return "Скоро истекают"
        case .fresh: return "В сроке"
        case .noShelfLife: return "Без срока"
        }
    }

    func matches(_ status: ExpirationStatus) -> Bool {
        switch (self, status) {
        case (.expired, .expired): return true
        case (.expiringSoon, .expiringSoon): return true
        case (.fresh, .ok): return true
        case (.noShelfLife, .noShelfLife): return true
        default: return false
        }
    }
}

// MARK: - FiltersPresentation

struct FiltersPresentation: Identifiable {
    let id = UUID()
    let availableCategories: [String]
    let current: WarehouseFilters
}

enum WarehouseSortOption: String, CaseIterable, Identifiable, Hashable {
    case newest
    case oldest
    case quantityAsc
    case quantityDesc
    case expirationAsc
    case nameAsc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Сначала новые"
        case .oldest: return "Сначала старые"
        case .quantityAsc: return "Меньше количество"
        case .quantityDesc: return "Больше количество"
        case .expirationAsc: return "Скорее истекает"
        case .nameAsc: return "По алфавиту"
        }
    }
}
