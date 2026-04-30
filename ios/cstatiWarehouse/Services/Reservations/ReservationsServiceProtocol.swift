//
//  ReservationsServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import Foundation

enum ReservationsError: Error {
    case unauthorized
    case forbidden
    case conflict(String)
    case notFound
    case validation(String)
    case server(String)
    case network(String)
    case unknown(String)

    var message: String {
        switch self {
        case .unauthorized:       return "Нужно войти заново"
        case .forbidden:          return "Нет прав на это действие"
        case .conflict(let m):    return m.isEmpty ? "Недостаточно доступного количества" : m
        case .notFound:           return "Бронь не найдена"
        case .validation(let m):  return m
        case .server(let m):      return m
        case .network(let m):     return m
        case .unknown(let m):     return m
        }
    }
}

struct CreateReservationParams {
    let quantity: Int
    let eventID: UUID?
    let expiresAt: Date?
    let notes: String

    init(
        quantity: Int,
        eventID: UUID? = nil,
        expiresAt: Date? = nil,
        notes: String = ""
    ) {
        self.quantity = quantity
        self.eventID = eventID
        self.expiresAt = expiresAt
        self.notes = notes
    }
}

protocol ReservationsServiceProtocol: AnyObject {
    func listByItem(
        itemID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    )

    func listByOrganization(
        organizationID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    )

    func availability(
        itemID: UUID,
        completion: @escaping (Result<ItemAvailability, ReservationsError>) -> Void
    )

    func create(
        itemID: UUID,
        params: CreateReservationParams,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    )

    func fulfill(
        reservationID: UUID,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    )

    func cancel(
        reservationID: UUID,
        cancellationReason: String,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    )
}
