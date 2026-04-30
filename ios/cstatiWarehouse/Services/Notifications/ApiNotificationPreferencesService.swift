//
//  ApiNotificationPreferencesService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

final class ApiNotificationPreferencesService: NotificationPreferencesServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch

    func fetch(completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void) {
        apiClient.request(
            path: "/notifications/preferences",
            method: .get,
            authenticated: true
        ) { (result: Result<NotificationPreferencesDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.toDomain()))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Update

    func update(
        patch: NotificationPreferencesPatch,
        completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void
    ) {
        let body = UpdatePreferencesBody(
            earlyWarningEnabled: patch.earlyWarningEnabled,
            actionRequiredEnabled: patch.actionRequiredEnabled,
            criticalEnabled: patch.criticalEnabled,
            expiredEnabled: patch.expiredEnabled,
            quietHoursStartMinute: patch.quietHoursStartMinute,
            quietHoursEndMinute: patch.quietHoursEndMinute,
            timezone: patch.timezone
        )
        apiClient.request(
            path: "/notifications/preferences",
            method: .put,
            body: body,
            authenticated: true
        ) { (result: Result<NotificationPreferencesDTO, APIError>) in
            switch result {
            case .success(let dto):
                completion(.success(dto.toDomain()))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Snooze

    func snooze(
        itemID: UUID,
        duration: TimeInterval,
        completion: @escaping (Result<Void, NotificationPreferencesError>) -> Void
    ) {
        let body = SnoozeBody(
            itemId: itemID.uuidString,
            duration: Self.formatDurationForBackend(duration)
        )
        apiClient.requestVoid(
            path: "/notifications/expiration/snooze",
            method: .post,
            body: body,
            authenticated: true
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Helpers

    private static func formatDurationForBackend(_ duration: TimeInterval) -> String {
        let hours = max(1, Int(duration / 3600.0))
        return "\(hours)h"
    }

    private static func mapError(_ error: APIError) -> NotificationPreferencesError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .server(let status, _, let message, _):
            let msg = message ?? "HTTP \(status)"
            if status == 422 || status == 400 { return .validation(msg) }
            return .server(msg)
        case .transport(let underlying):
            return .network(underlying.localizedDescription)
        case .decoding(let underlying):
            return .unknown("invalid response: \(underlying)")
        }
    }
}

// MARK: - DTO

// APIClient.decoder uses .convertFromSnakeCase — explicit snake_case CodingKeys
// would conflict (the strategy converts JSON keys BEFORE CodingKey matching).
// Property names must match the camelCase result of the conversion.
private struct NotificationPreferencesDTO: Decodable {
    let userId: String
    let earlyWarningEnabled: Bool
    let actionRequiredEnabled: Bool
    let criticalEnabled: Bool
    let expiredEnabled: Bool
    let quietHoursStartMinute: Int
    let quietHoursEndMinute: Int
    let timezone: String
    let updatedAt: Date

    func toDomain() -> NotificationPreferences {
        NotificationPreferences(
            earlyWarningEnabled: earlyWarningEnabled,
            actionRequiredEnabled: actionRequiredEnabled,
            criticalEnabled: criticalEnabled,
            expiredEnabled: expiredEnabled,
            quietHoursStartMinute: quietHoursStartMinute,
            quietHoursEndMinute: quietHoursEndMinute,
            timezone: timezone,
            updatedAt: updatedAt
        )
    }
}

// APIClient.encoder uses .convertToSnakeCase — camelCase property names auto-convert.
private struct UpdatePreferencesBody: Encodable {
    let earlyWarningEnabled: Bool?
    let actionRequiredEnabled: Bool?
    let criticalEnabled: Bool?
    let expiredEnabled: Bool?
    let quietHoursStartMinute: Int?
    let quietHoursEndMinute: Int?
    let timezone: String?
}

private struct SnoozeBody: Encodable {
    let itemId: String
    let duration: String
}
