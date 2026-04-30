//
//  ItemReservation.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import Foundation

enum ReservationStatus: String, Hashable, Codable, CaseIterable {
    case active
    case fulfilled
    case cancelled
    case expired

    var title: String {
        switch self {
        case .active:    return "Активна"
        case .fulfilled: return "Выполнена"
        case .cancelled: return "Отменена"
        case .expired:   return "Истекла"
        }
    }
}

struct ItemReservation: Identifiable, Hashable {
    let id: UUID
    let itemID: UUID
    let organizationID: UUID

    let quantity: Int
    let eventID: UUID?

    let reservedByUserID: UUID
    let reservedAt: Date
    let expiresAt: Date?

    let status: ReservationStatus

    let fulfilledAt: Date?
    let fulfilledByUserID: UUID?

    let cancelledAt: Date?
    let cancelledByUserID: UUID?
    let cancellationReason: String

    let notes: String
    let createdAt: Date
    let updatedAt: Date

    var isActive: Bool { status == .active }

    func isExpired(now: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}

struct ItemAvailability: Hashable {
    let itemID: UUID
    let total: Int
    let reserved: Int
    let available: Int
}
