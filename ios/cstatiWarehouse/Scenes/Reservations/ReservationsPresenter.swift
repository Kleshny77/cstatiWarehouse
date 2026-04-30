//
//  ReservationsPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import Foundation

@Observable
final class ReservationsPresenter {

    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum Filter: Hashable, CaseIterable {
        case all
        case active
        case fulfilled
        case cancelled
        case expired

        var title: String {
            switch self {
            case .all:       return "Все"
            case .active:    return "Активные"
            case .fulfilled: return "Выполнены"
            case .cancelled: return "Отменены"
            case .expired:   return "Истекли"
            }
        }

        var status: ReservationStatus? {
            switch self {
            case .all:       return nil
            case .active:    return .active
            case .fulfilled: return .fulfilled
            case .cancelled: return .cancelled
            case .expired:   return .expired
            }
        }
    }

    // MARK: - Public state

    private(set) var state: State = .loading
    private(set) var reservations: [ItemReservation] = []
    private(set) var availability: ItemAvailability?

    private(set) var memberDisplayNames: [UUID: String] = [:]
    private(set) var availableEvents: [OrgEvent] = []

    var filter: Filter = .all {
        didSet { if filter != oldValue { reload() } }
    }

    var isCreatePresented: Bool = false
    var isNewEventSheetPresented: Bool = false

    var draftQuantity: Int = 1
    var draftEventID: UUID?
    var draftHasExpiry: Bool = false
    var draftExpiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var draftNotes: String = ""

    private(set) var isSubmitting: Bool = false
    private(set) var isCreatingEvent: Bool = false
    var transientErrorMessage: String?

    // MARK: - Dependencies

    let item: Item
    private let organizationID: UUID
    private let currentUserID: UUID
    private let isCurrentUserAdmin: Bool
    private let service: ReservationsServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol
    private let eventsService: EventsServiceProtocol

    init(
        item: Item,
        organizationID: UUID,
        currentUserID: UUID,
        isCurrentUserAdmin: Bool,
        service: ReservationsServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        eventsService: EventsServiceProtocol
    ) {
        self.item = item
        self.organizationID = organizationID
        self.currentUserID = currentUserID
        self.isCurrentUserAdmin = isCurrentUserAdmin
        self.service = service
        self.organizationsService = organizationsService
        self.eventsService = eventsService
    }

    // MARK: - Lifecycle

    func onAppear() {
        loadMembers()
        loadEvents()
        reload()
    }

    func reload() {
        state = .loading
        reloadAvailability()
        service.listByItem(itemID: item.id, status: filter.status) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.reservations = list.sorted { $0.reservedAt > $1.reservedAt }
                self.state = .loaded
            case .failure(let err):
                self.state = .failed(err.message)
            }
        }
    }

    private func reloadAvailability() {
        service.availability(itemID: item.id) { [weak self] result in
            if case .success(let info) = result {
                self?.availability = info
            }
        }
    }

    // MARK: - Permissions

    func canFulfill(_ reservation: ItemReservation) -> Bool {
        guard reservation.status == .active else { return false }
        return reservation.reservedByUserID == currentUserID || isCurrentUserAdmin
    }

    func canCancel(_ reservation: ItemReservation) -> Bool {
        canFulfill(reservation)
    }

    func displayName(for userID: UUID) -> String {
        memberDisplayNames[userID] ?? "Пользователь"
    }

    func eventName(for eventID: UUID?) -> String? {
        guard let id = eventID else { return nil }
        return availableEvents.first(where: { $0.id == id })?.name
    }

    // MARK: - Compose

    func presentCreate() {
        let maxAvailable = availability?.available ?? item.quantity
        draftQuantity = max(1, min(1, max(1, maxAvailable)))
        draftEventID = nil
        draftHasExpiry = false
        draftExpiresAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        draftNotes = ""
        isCreatePresented = true
    }

    func dismissCreate() {
        isCreatePresented = false
    }

    var maxQuantityForDraft: Int {
        max(1, availability?.available ?? max(1, item.quantity))
    }

    func submitCreate() {
        let qty = max(1, min(draftQuantity, maxQuantityForDraft))
        guard !isSubmitting else { return }
        isSubmitting = true
        let params = CreateReservationParams(
            quantity: qty,
            eventID: draftEventID,
            expiresAt: draftHasExpiry ? draftExpiresAt : nil,
            notes: draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        service.create(itemID: item.id, params: params) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            switch result {
            case .success(let reservation):
                self.reservations.insert(reservation, at: 0)
                self.reloadAvailability()
                self.isCreatePresented = false
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    // MARK: - Actions

    func fulfill(_ reservation: ItemReservation) {
        guard canFulfill(reservation) else { return }
        service.fulfill(reservationID: reservation.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let updated):
                self.applyUpdate(updated)
                self.reloadAvailability()
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    func cancel(_ reservation: ItemReservation, reason: String) {
        guard canCancel(reservation) else { return }
        service.cancel(
            reservationID: reservation.id,
            cancellationReason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let updated):
                self.applyUpdate(updated)
                self.reloadAvailability()
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    // MARK: - Private

    private func applyUpdate(_ updated: ItemReservation) {
        if let i = reservations.firstIndex(where: { $0.id == updated.id }) {
            if let s = filter.status, s != updated.status {
                reservations.remove(at: i)
            } else {
                reservations[i] = updated
            }
        } else if filter == .all || filter.status == updated.status {
            reservations.insert(updated, at: 0)
        }
    }

    private func loadMembers() {
        organizationsService.fetchMembers(organizationID: organizationID) { [weak self] result in
            guard let self else { return }
            if case .success(let members) = result {
                var map: [UUID: String] = [:]
                for m in members {
                    if let n = m.fullName, !n.isEmpty {
                        map[m.userID] = n
                    } else if let e = m.email, !e.isEmpty {
                        map[m.userID] = e
                    } else {
                        map[m.userID] = "Пользователь"
                    }
                }
                self.memberDisplayNames = map
            }
        }
    }

    private func loadEvents() {
        eventsService.list(organizationID: organizationID) { [weak self] result in
            guard let self else { return }
            if case .success(let events) = result {
                self.availableEvents = events.sorted { ($0.startsAt ?? .distantFuture) > ($1.startsAt ?? .distantFuture) }
            }
        }
    }

    // MARK: - Create event inline

    func createNewEvent(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCreatingEvent else { return }
        isCreatingEvent = true
        eventsService.create(organizationID: organizationID, name: trimmed, description: "", startsAt: nil) { [weak self] result in
            guard let self else { return }
            self.isCreatingEvent = false
            switch result {
            case .success(let event):
                if !self.availableEvents.contains(where: { $0.id == event.id }) {
                    self.availableEvents.insert(event, at: 0)
                }
                self.draftEventID = event.id
                self.isNewEventSheetPresented = false
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }
}
