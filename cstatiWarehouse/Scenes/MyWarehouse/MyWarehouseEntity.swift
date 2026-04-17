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
