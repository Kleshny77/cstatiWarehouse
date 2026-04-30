//
//  ApiActivityService.swift
//  cstatiWarehouse
//
//  Created by Артём on 20.04.2026.
//

import Foundation

final class ApiActivityService: ActivityServiceProtocol {


    private let client: APIClient


    init(client: APIClient) {
        self.client = client
    }


    func list(organizationID: UUID, limit: Int?, completion: @escaping (Result<[ActivityEntry], ActivityError>) -> Void) {
        var query: [URLQueryItem] = []
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        client.request(
            path: "/organizations/\(organizationID.uuidString.lowercased())/activity",
            method: .get,
            query: query
        ) { (result: Result<ActivityListDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.entries.compactMap { $0.toDomain() }))
            case .failure(let error):
                completion(.failure(Self.mapError(error)))
            }
        }
    }


    private static func mapError(_ error: APIError) -> ActivityError {
        switch error {
        case .transport(let underlying):
            return .networkError(underlying)
        case .decoding:
            return .serverError("Некорректный ответ сервера")
        case .unauthorized:
            return .unauthorized
        case .server(let status, let code, let message, _):
            switch code {
            case "forbidden": return .forbidden
            case "not_found": return .notFound
            default:
                if status == 403 { return .forbidden }
                if status == 404 { return .notFound }
                return .serverError(message ?? "Ошибка сервера (\(status))")
            }
        }
    }
}


private struct ActivityListDTO: Decodable {
    let entries: [ActivityEntryDTO]
}

private struct ActivityEntryDTO: Decodable {
    let id: String
    let organizationId: String
    let actorUserId: String
    let actorName: String?
    let kind: String
    let targetType: String?
    let targetId: String?
    let summary: String
    let createdAt: Date

    func toDomain() -> ActivityEntry? {
        guard let id = UUID(uuidString: id),
              let orgID = UUID(uuidString: organizationId),
              let actor = UUID(uuidString: actorUserId) else { return nil }
        return ActivityEntry(
            id: id,
            organizationID: orgID,
            actorUserID: actor,
            actorDisplayName: actorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            kind: kind,
            targetType: targetType ?? "",
            targetID: targetId.flatMap { UUID(uuidString: $0) },
            summary: summary,
            createdAt: createdAt
        )
    }
}
