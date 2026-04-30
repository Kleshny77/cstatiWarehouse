//
//  ApiReservationsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import Foundation

final class ApiReservationsService: ReservationsServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List

    func listByItem(
        itemID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    ) {
        apiClient.request(
            path: "/items/\(itemID.uuidString.lowercased())/reservations",
            method: .get,
            query: Self.statusQuery(status),
            authenticated: true
        ) { (result: Result<ReservationsListDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.items.compactMap { $0.toDomain() }))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    func listByOrganization(
        organizationID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    ) {
        apiClient.request(
            path: "/organizations/\(organizationID.uuidString.lowercased())/reservations",
            method: .get,
            query: Self.statusQuery(status),
            authenticated: true
        ) { (result: Result<ReservationsListDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.items.compactMap { $0.toDomain() }))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Availability

    func availability(
        itemID: UUID,
        completion: @escaping (Result<ItemAvailability, ReservationsError>) -> Void
    ) {
        apiClient.request(
            path: "/items/\(itemID.uuidString.lowercased())/availability",
            method: .get,
            authenticated: true
        ) { (result: Result<AvailabilityDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid availability payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Create

    func create(
        itemID: UUID,
        params: CreateReservationParams,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    ) {
        let body = CreateReservationBody(
            quantity: params.quantity,
            eventId: params.eventID?.uuidString.lowercased(),
            expiresAt: params.expiresAt.map { Self.iso8601.string(from: $0) },
            notes: params.notes
        )
        apiClient.request(
            path: "/items/\(itemID.uuidString.lowercased())/reservations",
            method: .post,
            body: body,
            authenticated: true
        ) { (result: Result<ItemReservationDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid reservation payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Fulfill / Cancel

    func fulfill(
        reservationID: UUID,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    ) {
        apiClient.request(
            path: "/reservations/\(reservationID.uuidString.lowercased())/fulfill",
            method: .post,
            authenticated: true
        ) { (result: Result<ItemReservationDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid reservation payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    func cancel(
        reservationID: UUID,
        cancellationReason: String,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    ) {
        let body = CancelReservationBody(cancellationReason: cancellationReason)
        apiClient.request(
            path: "/reservations/\(reservationID.uuidString.lowercased())/cancel",
            method: .post,
            body: body,
            authenticated: true
        ) { (result: Result<ItemReservationDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid reservation payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Helpers

    private static func statusQuery(_ status: ReservationStatus?) -> [URLQueryItem] {
        guard let s = status else { return [] }
        return [URLQueryItem(name: "status", value: s.rawValue)]
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func mapError(_ error: APIError) -> ReservationsError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .server(let status, _, let message, _):
            let msg = message ?? "HTTP \(status)"
            switch status {
            case 400, 422: return .validation(msg)
            case 403:      return .forbidden
            case 404:      return .notFound
            case 409:      return .conflict(msg)
            default:       return .server(msg)
            }
        case .transport(let underlying):
            return .network(underlying.localizedDescription)
        case .decoding:
            return .unknown("invalid response")
        }
    }
}

// MARK: - DTO


private struct ReservationsListDTO: Decodable {
    let items: [ItemReservationDTO]
}

private struct AvailabilityDTO: Decodable {
    let itemId: String
    let total: Int
    let reserved: Int
    let available: Int

    func toDomain() -> ItemAvailability? {
        guard let uuid = UUID(uuidString: itemId) else { return nil }
        return ItemAvailability(itemID: uuid, total: total, reserved: reserved, available: available)
    }
}

private struct ItemReservationDTO: Decodable {
    let id: String
    let itemId: String
    let organizationId: String

    let quantity: Int
    let eventId: String?

    let reservedByUserId: String
    let reservedAt: Date
    let expiresAt: Date?

    let status: String

    let fulfilledAt: Date?
    let fulfilledByUserId: String?

    let cancelledAt: Date?
    let cancelledByUserId: String?
    let cancellationReason: String

    let notes: String
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> ItemReservation? {
        guard
            let idValue     = UUID(uuidString: id),
            let itemUUID    = UUID(uuidString: itemId),
            let orgUUID     = UUID(uuidString: organizationId),
            let reservedBy  = UUID(uuidString: reservedByUserId),
            let statusValue = ReservationStatus(rawValue: status)
        else { return nil }
        let fulfilledBy = fulfilledByUserId.flatMap { UUID(uuidString: $0) }
        let cancelledBy = cancelledByUserId.flatMap { UUID(uuidString: $0) }
        let event = eventId.flatMap { UUID(uuidString: $0) }
        return ItemReservation(
            id: idValue,
            itemID: itemUUID,
            organizationID: orgUUID,
            quantity: quantity,
            eventID: event,
            reservedByUserID: reservedBy,
            reservedAt: reservedAt,
            expiresAt: expiresAt,
            status: statusValue,
            fulfilledAt: fulfilledAt,
            fulfilledByUserID: fulfilledBy,
            cancelledAt: cancelledAt,
            cancelledByUserID: cancelledBy,
            cancellationReason: cancellationReason,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Request bodies

// APIClient.encoder uses .convertToSnakeCase — camelCase property names auto-convert.
// Avoid consecutive capitals (like "ID") so the conversion is unambiguous.
private struct CreateReservationBody: Encodable {
    let quantity: Int
    let eventId: String?
    let expiresAt: String?
    let notes: String
}

private struct CancelReservationBody: Encodable {
    let cancellationReason: String
}
