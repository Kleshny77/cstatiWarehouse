//
//  WarehouseItemsCacheCodec.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum WarehouseItemsCacheCodec {

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func encodeItems(_ items: [Item]) throws -> Data {
        let envelope = WarehouseItemsEnvelope(items: items.map { WarehouseWireItem(encoding: $0) })
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    static func decodeItems(from data: Data) throws -> [Item] {
        let decoder = makeJSONDecoder()
        let envelope = try decoder.decode(WarehouseItemsEnvelope.self, from: data)
        return envelope.items.compactMap { $0.toItem() }
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = iso8601Fractional.date(from: str) {
                return date
            }
            if let date = iso8601Basic.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(str)"
            )
        }
        return decoder
    }
}

private struct WarehouseItemsEnvelope: Codable {
    let items: [WarehouseWireItem]
}

private struct WarehouseWireItem: Codable {
    let id: String
    let heldByUserId: String?
    let name: String
    let description: String
    let categoryName: String
    let quantity: Int
    let status: String
    let archiveReason: String?
    let archivedAt: Date?
    let expirationDate: Date?
    let imageUrl: String?
    let locationAddress: String?
    let parentItemId: String?
    let variantLabel: String?
    let measureUnit: String?
    let volumePerUnit: Double?
    let variants: [WarehouseWireItem]?
    let aggregatedVolumeLiters: Double?
    let createdAt: Date
    let updatedAt: Date

    init(encoding item: Item) {
        id = item.id.uuidString.lowercased()
        heldByUserId = item.heldByUserID?.uuidString.lowercased()
        name = item.name
        description = item.description ?? ""
        categoryName = item.categoryName
        quantity = item.quantity
        switch item.status {
        case .inStock:
            status = "in_stock"
            archiveReason = nil
            archivedAt = nil
        case .archived(let reason, let at):
            status = "archived"
            archiveReason = reason.rawValue
            archivedAt = at
        }
        expirationDate = item.expirationDate
        imageUrl = item.imageURL?.absoluteString
        locationAddress = item.locationAddress.isEmpty ? nil : item.locationAddress
        parentItemId = item.parentItemID?.uuidString.lowercased()
        variantLabel = item.variantLabel.isEmpty ? nil : item.variantLabel
        measureUnit = item.measureUnit.rawValue
        volumePerUnit = item.volumePerUnit
        let children = item.variants.map { WarehouseWireItem(encoding: $0) }
        variants = children.isEmpty ? nil : children
        aggregatedVolumeLiters = item.aggregatedVolumeLiters
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }

    func toItem() -> Item? {
        guard let uuid = UUID(uuidString: id) else { return nil }

        let status: ItemStatus
        switch self.status {
        case "in_stock":
            status = .inStock
        case "archived":
            let reason = archiveReason.flatMap(ArchiveReason.init(rawValue:)) ?? .other
            let archivedAt = archivedAt ?? updatedAt
            status = .archived(reason: reason, at: archivedAt)
        default:
            return nil
        }

        let imageURL = imageUrl.flatMap { URL(string: $0) }
        let holder = heldByUserId.flatMap { UUID(uuidString: $0) }
        let parentUUID = parentItemId.flatMap(UUID.init(uuidString:))
        let mu = ItemMeasureUnit.fromAPI(measureUnit)
        let vLabel = variantLabel ?? ""
        let childItems = (variants ?? []).compactMap { $0.toItem() }
        return Item(
            id: uuid,
            name: name,
            description: description.isEmpty ? nil : description,
            categoryName: categoryName,
            quantity: quantity,
            expirationDate: expirationDate,
            imageURL: imageURL,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            heldByUserID: holder,
            locationAddress: locationAddress ?? "",
            parentItemID: parentUUID,
            variantLabel: vLabel,
            measureUnit: mu,
            volumePerUnit: volumePerUnit,
            variants: childItems,
            aggregatedVolumeLiters: aggregatedVolumeLiters
        )
    }
}
