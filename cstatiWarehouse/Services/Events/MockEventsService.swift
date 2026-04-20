//
//  MockEventsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class MockEventsService: EventsServiceProtocol {

    private var storage: [UUID: [OrgEvent]] = [:]
    private let userID = UUID()

    func list(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void) {
        completion(.success(storage[organizationID] ?? []))
    }

    func create(organizationID: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.validationError("Укажите название")))
            return
        }
        let event = OrgEvent(
            id: UUID(),
            organizationID: organizationID,
            name: trimmed,
            description: description,
            startsAt: startsAt,
            createdByID: userID,
            createdAt: .now,
            updatedAt: .now
        )
        storage[organizationID, default: []].append(event)
        completion(.success(event))
    }

    func update(id: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        for (orgID, events) in storage {
            if let index = events.firstIndex(where: { $0.id == id }) {
                var updated = events[index]
                updated.name = name
                updated.description = description
                updated.startsAt = startsAt
                updated.updatedAt = .now
                storage[orgID]?[index] = updated
                completion(.success(updated))
                return
            }
        }
        completion(.failure(.notFound))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, EventsError>) -> Void) {
        for (orgID, events) in storage {
            if events.contains(where: { $0.id == id }) {
                storage[orgID]?.removeAll(where: { $0.id == id })
                completion(.success(()))
                return
            }
        }
        completion(.failure(.notFound))
    }
}
