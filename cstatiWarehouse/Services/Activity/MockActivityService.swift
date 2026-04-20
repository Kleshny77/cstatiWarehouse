//
//  MockActivityService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class MockActivityService: ActivityServiceProtocol {

    func list(organizationID: UUID, limit: Int?, completion: @escaping (Result<[ActivityEntry], ActivityError>) -> Void) {
        completion(.success([
            ActivityEntry(
                id: UUID(),
                organizationID: organizationID,
                actorUserID: UUID(),
                actorDisplayName: "Вы",
                kind: "item.created",
                targetType: "item",
                targetID: nil,
                summary: "Пример записи",
                createdAt: .now
            )
        ]))
    }
}
