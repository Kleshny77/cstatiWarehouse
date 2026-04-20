//
//  ApiEventsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class ApiEventsService: EventsServiceProtocol {

    // MARK: Properties

    private let client: APIClient

    // MARK: Lifecycle

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Public Methods

    func list(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void) {
        let query = [URLQueryItem(name: "organizationId", value: organizationID.uuidString.lowercased())]
        client.request(
            path: "/events",
            method: .get,
            query: query
        ) { (result: Result<EventsListDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.events.compactMap { $0.toDomain() }))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }

    func create(organizationID: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        let body = CreateEventRequestDTO(
            organizationId: organizationID.uuidString.lowercased(),
            name: name,
            description: description,
            startsAt: startsAt
        )
        client.request(
            path: "/events",
            method: .post,
            body: body
        ) { (result: Result<EventResponseDTO, APIError>) in
            completion(Self.mapSingle(result))
        }
    }

    func update(id: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        let body = UpdateEventRequestDTO(
            name: name,
            description: description,
            startsAt: startsAt
        )
        client.request(
            path: "/events/\(id.uuidString.lowercased())",
            method: .patch,
            body: body
        ) { (result: Result<EventResponseDTO, APIError>) in
            completion(Self.mapSingle(result))
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, EventsError>) -> Void) {
        client.requestVoid(
            path: "/events/\(id.uuidString.lowercased())",
            method: .delete
        ) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let error): completion(.failure(Self.mapError(error)))
            }
        }
    }

    // MARK: Private Methods

    private static func mapSingle(_ result: Result<EventResponseDTO, APIError>) -> Result<OrgEvent, EventsError> {
        switch result {
        case .success(let dto):
            guard let event = dto.event.toDomain() else {
                return .failure(.serverError("Некорректный ответ сервера"))
            }
            return .success(event)
        case .failure(let error):
            return .failure(mapError(error))
        }
    }

    private static func mapError(_ error: APIError) -> EventsError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message):
            switch code {
            case "not_found": return .notFound
            case "forbidden": return .forbidden
            case "validation_error": return .validationError(message ?? "Некорректные данные")
            default:
                if status == 403 { return .forbidden }
                if status == 404 { return .notFound }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}

// MARK: - DTOs

private struct EventsListDTO: Decodable {
    let events: [EventDTO]
}

private struct EventResponseDTO: Decodable {
    let event: EventDTO
}

private struct CreateEventRequestDTO: Encodable {
    let organizationId: String
    let name: String
    let description: String
    let startsAt: Date?
}

private struct UpdateEventRequestDTO: Encodable {
    let name: String
    let description: String
    let startsAt: Date?
}

private struct EventDTO: Decodable {
    let id: String
    let organizationId: String
    let createdById: String
    let name: String
    let description: String
    let startsAt: Date?
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> OrgEvent? {
        guard let id = UUID(uuidString: id),
              let orgID = UUID(uuidString: organizationId),
              let createdBy = UUID(uuidString: createdById) else { return nil }
        return OrgEvent(
            id: id,
            organizationID: orgID,
            name: name,
            description: description,
            startsAt: startsAt,
            createdByID: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
