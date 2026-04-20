//
//  MockOrgCategoriesService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class MockOrgCategoriesService: OrgCategoriesServiceProtocol {

    private var storage: [UUID: [OrgCategory]] = [:]
    private let userID = UUID()

    func list(organizationID: UUID, completion: @escaping (Result<[OrgCategory], OrgCategoriesError>) -> Void) {
        completion(.success(storage[organizationID] ?? []))
    }

    func create(organizationID: UUID, name: String, completion: @escaping (Result<OrgCategory, OrgCategoriesError>) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.validationError("Укажите название")))
            return
        }
        let existing = storage[organizationID] ?? []
        if existing.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            completion(.failure(.conflict("")))
            return
        }
        let category = OrgCategory(
            id: UUID(),
            organizationID: organizationID,
            name: trimmed,
            createdByID: userID,
            createdAt: .now
        )
        storage[organizationID, default: []].append(category)
        completion(.success(category))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, OrgCategoriesError>) -> Void) {
        for (orgID, cats) in storage {
            if cats.contains(where: { $0.id == id }) {
                storage[orgID]?.removeAll(where: { $0.id == id })
                completion(.success(()))
                return
            }
        }
        completion(.failure(.notFound))
    }
}
