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
    /// Уже загруженное на сервер изображение позиции (приходит в режиме edit).
    var existingImageURL: URL?
    /// Выбранное пользователем новое фото; если задано — перекрывает `existingImageURL` при сохранении.
    var pickedImage: UIImage?
    /// Адрес размещения позиции (необязательно).
    var locationAddress: String
    /// Текущий держатель позиции. В режиме create задаётся снаружи (текущий пользователь).
    var holderID: UUID?

    static func from(item: Item) -> ItemEditDraft {
        ItemEditDraft(
            name: item.name,
            description: item.description ?? "",
            categoryName: item.categoryName,
            quantity: item.quantity,
            hasShelfLife: item.expirationDate != nil,
            expirationDate: item.expirationDate ?? .now,
            existingImageURL: item.imageURL,
            pickedImage: nil,
            locationAddress: item.locationAddress ?? "",
            holderID: item.heldByUserID
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
            holderID: nil
        )
    }
}
