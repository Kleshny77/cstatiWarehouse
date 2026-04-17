//
//  ItemEditEntity.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

struct ItemEditDraft {
    var name: String
    var description: String
    var categoryName: String
    var quantity: Int
    var hasShelfLife: Bool
    var expirationDate: Date
    
    static func from(item: Item) -> ItemEditDraft {
        ItemEditDraft(
            name: item.name,
            description: item.description ?? "",
            categoryName: item.categoryName,
            quantity: item.quantity,
            hasShelfLife: item.expirationDate != nil,
            expirationDate: item.expirationDate ?? .now
        )
    }
    
    static func empty(suggestedCategory: String?) -> ItemEditDraft {
        ItemEditDraft(
            name: "",
            description: "",
            categoryName: suggestedCategory ?? "",
            quantity: 1,
            hasShelfLife: false,
            expirationDate: .now
        )
    }
}
