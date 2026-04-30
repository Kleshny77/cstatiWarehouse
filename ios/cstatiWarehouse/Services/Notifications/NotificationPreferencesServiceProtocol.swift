//
//  NotificationPreferencesServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum ExpirationLevel: String, CaseIterable, Hashable, Codable {
    case earlyWarning = "early_warning"      // 7 дней
    case actionRequired = "action_required"  // 3 дня
    case critical = "critical"               // 1 день — time-sensitive
    case expired = "expired"                 // день истечения и позже

    var thresholdDays: Int {
        switch self {
        case .earlyWarning: return 7
        case .actionRequired: return 3
        case .critical: return 1
        case .expired: return 0
        }
    }

    var localizedTitle: String {
        switch self {
        case .earlyWarning: return "За 7 дней"
        case .actionRequired: return "За 3 дня"
        case .critical: return "За 1 день (срочно)"
        case .expired: return "В день истечения"
        }
    }

    var localizedHint: String {
        switch self {
        case .earlyWarning: return "Заранее планировать использование"
        case .actionRequired: return "Активное напоминание действовать"
        case .critical: return "Критично — приходит даже в тихие часы"
        case .expired: return "Архивировать просроченное"
        }
    }
}

struct NotificationPreferences: Hashable, Codable {
    var earlyWarningEnabled: Bool
    var actionRequiredEnabled: Bool
    var criticalEnabled: Bool
    var expiredEnabled: Bool
    var quietHoursStartMinute: Int
    var quietHoursEndMinute: Int
    var timezone: String
    var updatedAt: Date

    static func defaults(now: Date = .now) -> NotificationPreferences {
        NotificationPreferences(
            earlyWarningEnabled: true,
            actionRequiredEnabled: true,
            criticalEnabled: true,
            expiredEnabled: true,
            quietHoursStartMinute: 22 * 60,
            quietHoursEndMinute: 8 * 60,
            timezone: TimeZone.current.identifier,
            updatedAt: now
        )
    }

    func isEnabled(_ level: ExpirationLevel) -> Bool {
        switch level {
        case .earlyWarning: return earlyWarningEnabled
        case .actionRequired: return actionRequiredEnabled
        case .critical: return criticalEnabled
        case .expired: return expiredEnabled
        }
    }

    mutating func setEnabled(_ enabled: Bool, for level: ExpirationLevel) {
        switch level {
        case .earlyWarning: earlyWarningEnabled = enabled
        case .actionRequired: actionRequiredEnabled = enabled
        case .critical: criticalEnabled = enabled
        case .expired: expiredEnabled = enabled
        }
    }
}

struct NotificationPreferencesPatch {
    var earlyWarningEnabled: Bool?
    var actionRequiredEnabled: Bool?
    var criticalEnabled: Bool?
    var expiredEnabled: Bool?
    var quietHoursStartMinute: Int?
    var quietHoursEndMinute: Int?
    var timezone: String?
}

enum NotificationPreferencesError: Error {
    case unauthorized
    case network(String)
    case server(String)
    case validation(String)
    case unknown(String)

    var message: String {
        switch self {
        case .unauthorized: return "Нужно войти заново"
        case .network(let m): return "Нет соединения. \(m)"
        case .server(let m): return "Ошибка сервера. \(m)"
        case .validation(let m): return m
        case .unknown(let m): return "Неизвестная ошибка. \(m)"
        }
    }
}

protocol NotificationPreferencesServiceProtocol: AnyObject {
    func fetch(completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void)
    func update(
        patch: NotificationPreferencesPatch,
        completion: @escaping (Result<NotificationPreferences, NotificationPreferencesError>) -> Void
    )
    func snooze(
        itemID: UUID,
        duration: TimeInterval,
        completion: @escaping (Result<Void, NotificationPreferencesError>) -> Void
    )
}
