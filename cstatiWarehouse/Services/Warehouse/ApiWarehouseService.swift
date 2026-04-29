//
//  ApiWarehouseService.swift
//  cstatiWarehouse
//
//  Created by Артём on 19.04.2026.
//

import Foundation

/// Реализация WarehouseServiceProtocol поверх REST API бэкенда.
/// Все эндпоинты требуют Bearer access-token, APIClient сам подхватит его.
final class ApiWarehouseService: WarehouseServiceProtocol {

    // MARK: Properties

    private let client: APIClient

    // MARK: Lifecycle

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Public Methods

    func fetchActiveItems(organizationID: UUID, scope: WarehouseScope, completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        fetchItems(statusFilter: "in_stock", scope: scope, organizationID: organizationID, completion: completion)
    }

    func fetchHistory(organizationID: UUID, completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
        // Для истории явно просим `all`: admin/owner увидят архив всей организации,
        // для обычного участника бэкенд всё равно сузит выдачу до собственных позиций.
        fetchItems(statusFilter: "archived", scope: .all, organizationID: organizationID, completion: completion)
    }

    func fetchArchiveEvents(organizationID: UUID, completion: @escaping (Result<[ArchiveEvent], WarehouseError>) -> Void) {
        client.request(
            path: "/archive-events",
            method: .get,
            query: [URLQueryItem(name: "organizationId", value: organizationID.uuidString.lowercased())]
        ) { (result: Result<ArchiveEventsResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                let events = dto.events.compactMap { $0.toDomain() }
                completion(.success(events))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func fetchCategories(organizationID: UUID, completion: @escaping (Result<[String], WarehouseError>) -> Void) {
        client.request(
            path: "/categories",
            method: .get,
            query: [URLQueryItem(name: "organizationId", value: organizationID.uuidString.lowercased())]
        ) { (result: Result<CategoriesResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.categories))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func createItem(_ item: Item, organizationID: UUID, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        let body = CreateItemRequestDTO(item: item, organizationID: organizationID)
        client.request(
            path: "/items",
            method: .post,
            body: body
        ) { (result: Result<ItemResponseDTO, APIError>) in
            completion(Self.mapItemResult(result))
        }
    }

    func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
        let body = UpdateItemRequestDTO(item: item)
        client.request(
            path: "/items/\(item.id.uuidString.lowercased())",
            method: .put,
            body: body
        ) { (result: Result<ItemResponseDTO, APIError>) in
            completion(Self.mapItemResult(result))
        }
    }

    func archiveItem(
        id: UUID,
        quantity: Int,
        reason: ArchiveReason,
        reasonDetail: String,
        eventID: UUID?,
        completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
    ) {
        let body = ArchiveRequestDTO(
            quantity: quantity,
            reason: reason.rawValue,
            reasonDetail: reasonDetail.isEmpty ? nil : reasonDetail,
            eventId: eventID?.uuidString.lowercased()
        )
        client.request(
            path: "/items/\(id.uuidString.lowercased())/archive",
            method: .post,
            body: body
        ) { (result: Result<ArchiveResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                guard let item = dto.item.toItem(), let event = dto.event.toDomain() else {
                    completion(.failure(.serverError("Некорректный ответ сервера")))
                    return
                }
                completion(.success(ArchiveResult(item: item, event: event)))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void) {
        client.requestVoid(
            path: "/items/\(id.uuidString.lowercased())",
            method: .delete
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    // MARK: Private Methods

    private func fetchItems(
        statusFilter: String?,
        scope: WarehouseScope?,
        organizationID: UUID,
        completion: @escaping (Result<[Item], WarehouseError>) -> Void
    ) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "organizationId", value: organizationID.uuidString.lowercased())
        ]
        if let statusFilter = statusFilter {
            query.append(URLQueryItem(name: "status", value: statusFilter))
        }
        if let scope = scope {
            query.append(URLQueryItem(name: "scope", value: scope.rawValue))
        }
        client.request(
            path: "/items",
            method: .get,
            query: query
        ) { (result: Result<ItemListResponseDTO, APIError>) in
            switch result {
            case .success(let dto):
                let items = dto.items.compactMap { $0.toItem() }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    private static func mapItemResult(_ result: Result<ItemResponseDTO, APIError>) -> Result<Item, WarehouseError> {
        switch result {
        case .success(let dto):
            guard let item = dto.item.toItem() else {
                return .failure(.serverError("Некорректный ответ сервера"))
            }
            return .success(item)
        case .failure(let error):
            return .failure(mapError(error))
        }
    }

    private static func mapError(_ error: APIError) -> WarehouseError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message):
            switch code {
            case "not_found":
                return .notFound
            case "forbidden":
                return .forbidden
            case "validation_error":
                return .validationError(message ?? "Некорректные данные")
            default:
                if status == 403 { return .forbidden }
                if status == 404 { return .notFound }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}

// MARK: - DTOs

private struct ItemListResponseDTO: Decodable {
    let items: [ItemDTO]
}

private struct ItemResponseDTO: Decodable {
    let item: ItemDTO
}

private struct CategoriesResponseDTO: Decodable {
    let categories: [String]
}

private struct ArchiveResponseDTO: Decodable {
    let item: ItemDTO
    let event: ArchiveEventDTO
}

private struct ArchiveEventsResponseDTO: Decodable {
    let events: [ArchiveEventDTO]
}

private struct ArchiveRequestDTO: Encodable {
    let quantity: Int
    let reason: String
    let reasonDetail: String?
    let eventId: String?
}

private struct CreateItemRequestDTO: Encodable {
    let organizationId: String
    let heldByUserId: String?
    let name: String
    let description: String
    let categoryName: String
    let quantity: Int
    let expirationDate: Date?
    let imageUrl: String?
    let locationAddress: String?
    let parentItemId: String?
    let variantLabel: String
    let measureUnit: String
    let volumePerUnit: Double?

    init(item: Item, organizationID: UUID) {
        self.organizationId = organizationID.uuidString.lowercased()
        self.heldByUserId = item.heldByUserID?.uuidString.lowercased()
        self.name = item.name
        self.description = item.description ?? ""
        self.categoryName = item.categoryName
        self.quantity = item.quantity
        self.expirationDate = item.expirationDate
        self.imageUrl = item.imageURL?.absoluteString
        self.locationAddress = item.locationAddress
        self.parentItemId = item.parentItemID?.uuidString.lowercased()
        self.variantLabel = item.variantLabel
        self.measureUnit = item.measureUnit.rawValue
        self.volumePerUnit = item.volumePerUnit
    }
}

private struct UpdateItemRequestDTO: Encodable {
    let heldByUserId: String?
    let name: String
    let description: String
    let categoryName: String
    let quantity: Int
    let expirationDate: Date?
    let imageUrl: String?
    let locationAddress: String?
    let variantLabel: String
    let measureUnit: String
    let volumePerUnit: Double?

    init(item: Item) {
        self.heldByUserId = item.heldByUserID?.uuidString.lowercased()
        self.name = item.name
        self.description = item.description ?? ""
        self.categoryName = item.categoryName
        self.quantity = item.quantity
        self.expirationDate = item.expirationDate
        self.imageUrl = item.imageURL?.absoluteString
        self.locationAddress = item.locationAddress
        self.variantLabel = item.variantLabel
        self.measureUnit = item.measureUnit.rawValue
        self.volumePerUnit = item.volumePerUnit
    }
}

private struct ItemDTO: Decodable {
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
    let variants: [ItemDTO]?
    let aggregatedVolumeLiters: Double?
    let createdAt: Date
    let updatedAt: Date

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
        let mu = ItemMeasureUnit(rawValue: measureUnit ?? "piece") ?? .piece
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
            status: status,
            heldByUserID: holder,
            locationAddress: locationAddress,
            parentItemID: parentUUID,
            variantLabel: vLabel,
            measureUnit: mu,
            volumePerUnit: volumePerUnit,
            variants: childItems,
            aggregatedVolumeLiters: aggregatedVolumeLiters
        )
    }
}

private struct ArchiveEventDTO: Decodable {
    let id: String
    let itemId: String
    let archivedByUserId: String
    let itemName: String?
    let archivedByDisplayName: String?
    let quantity: Int
    let reason: String
    let reasonDetail: String?
    let archivedAt: Date

    func toDomain() -> ArchiveEvent? {
        guard let id = UUID(uuidString: id),
              let itemId = UUID(uuidString: itemId),
              let actorId = UUID(uuidString: archivedByUserId) else { return nil }
        let reason = ArchiveReason(rawValue: reason) ?? .other
        let name = (itemName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let actorName = (archivedByDisplayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ArchiveEvent(
            id: id,
            itemID: itemId,
            itemName: name.isEmpty ? "Позиция" : name,
            quantity: quantity,
            reason: reason,
            reasonDetail: reasonDetail ?? "",
            archivedAt: archivedAt,
            archivedByUserID: actorId,
            archivedByDisplayName: actorName
        )
    }
}
