//
//  ItemEditEntity.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit

struct ItemEditDraft {
    var name: String
    var description: String
    var categoryName: String
    var quantity: Int
    var hasShelfLife: Bool
    var expirationDate: Date
    var existingImageURL: URL?
    var pickedImage: UIImage?
    var locationAddress: String
    var holderID: UUID?
    var isMultiPackGroup: Bool
    var measureUnit: ItemMeasureUnit
    /// Размер одной упаковки в выбранной мере (строка для поля ввода).
    var volumePerUnitText: String
    var variantLabel: String

    static func from(item: Item) -> ItemEditDraft {
        let volText: String
        if let v = item.volumePerUnit {
            volText = ItemEditDraft.formatVolume(v)
        } else {
            volText = "1"
        }
        return ItemEditDraft(
            name: item.name,
            description: item.description ?? "",
            categoryName: item.categoryName,
            quantity: item.quantity,
            hasShelfLife: item.expirationDate != nil,
            expirationDate: item.expirationDate ?? .now,
            existingImageURL: item.imageURL,
            pickedImage: nil,
            locationAddress: item.locationAddress,
            holderID: item.heldByUserID,
            isMultiPackGroup: false,
            measureUnit: item.measureUnit,
            volumePerUnitText: volText,
            variantLabel: item.variantLabel
        )
    }

    static func empty(suggestedCategory: String?) -> ItemEditDraft {
        ItemEditDraft(
            name: "",
            description: "",
            categoryName: suggestedCategory ?? "",
            quantity: 1,
            hasShelfLife: false,
            expirationDate: .now,
            existingImageURL: nil,
            pickedImage: nil,
            locationAddress: "",
            holderID: nil,
            isMultiPackGroup: false,
            measureUnit: .piece,
            volumePerUnitText: "1",
            variantLabel: ""
        )
    }

    static func forNewVariant(parent: Item) -> ItemEditDraft {
        ItemEditDraft(
            name: parent.name,
            description: "",
            categoryName: parent.categoryName,
            quantity: 1,
            hasShelfLife: false,
            expirationDate: .now,
            existingImageURL: nil,
            pickedImage: nil,
            locationAddress: parent.locationAddress,
            holderID: parent.heldByUserID,
            isMultiPackGroup: false,
            measureUnit: .liter,
            volumePerUnitText: "1",
            variantLabel: ""
        )
    }

    private static func formatVolume(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}
