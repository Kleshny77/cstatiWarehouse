//
//  ReservationsPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct ReservationsPresenterTests {
    @Test
    func filter_mapsToOptionalReservationStatus() {
        #expect(ReservationsPresenter.Filter.all.status == nil)
        #expect(ReservationsPresenter.Filter.active.status == .active)
        #expect(ReservationsPresenter.Filter.fulfilled.status == .fulfilled)
        #expect(ReservationsPresenter.Filter.cancelled.status == .cancelled)
        #expect(ReservationsPresenter.Filter.expired.status == .expired)
    }

    @Test
    func canFulfill_ownerWhenActive_returnsTrue() {
        let uid = UUID()
        let sut = makeSUT(currentUserID: uid, isAdmin: false)
        let r = makeReservation(reservedBy: uid, status: .active)
        #expect(sut.canFulfill(r))
    }

    @Test
    func canFulfill_nonOwnerNonAdmin_returnsFalse() {
        let uid = UUID()
        let sut = makeSUT(currentUserID: uid, isAdmin: false)
        let r = makeReservation(reservedBy: UUID(), status: .active)
        #expect(sut.canFulfill(r) == false)
    }

    @Test
    func canFulfill_adminCanFulfillOthersReservation() {
        let uid = UUID()
        let sut = makeSUT(currentUserID: uid, isAdmin: true)
        let r = makeReservation(reservedBy: UUID(), status: .active)
        #expect(sut.canFulfill(r))
    }

    @Test
    func canFulfill_notActive_returnsFalse() {
        let uid = UUID()
        let sut = makeSUT(currentUserID: uid, isAdmin: true)
        let r = makeReservation(reservedBy: uid, status: .fulfilled)
        #expect(sut.canFulfill(r) == false)
    }

    @Test
    func displayName_usesMemberFullName() {
        let memberID = UUID()
        let orgID = UUID()
        let item = Item(name: "Позиция", categoryName: "c", quantity: 5)
        let org = ReservationsPresenterTestOrgService()
        org.members = [
            OrganizationMember(
                userID: memberID,
                organizationID: orgID,
                role: .member,
                joinedAt: .now,
                name: "Иван",
                lastName: "Петров",
                email: nil,
                avatarURL: nil
            )
        ]
        let sut = ReservationsPresenter(
            item: item,
            organizationID: orgID,
            currentUserID: UUID(),
            isCurrentUserAdmin: false,
            service: ReservationsServiceListNoop(),
            organizationsService: org,
            eventsService: ReservationsEventsNoop()
        )
        sut.onAppear()
        #expect(sut.displayName(for: memberID) == "Иван Петров")
    }

    @Test
    func eventName_resolvesFromLoadedEvents() {
        let orgID = UUID()
        let eventID = UUID()
        let item = Item(name: "Позиция", categoryName: "c", quantity: 3)
        let events = ReservationsEventsNoop()
        events.events = [
            OrgEvent(
                id: eventID,
                organizationID: orgID,
                name: "Фестиваль",
                description: "",
                startsAt: nil,
                createdByID: UUID(),
                createdAt: .now,
                updatedAt: .now
            )
        ]
        let sut = ReservationsPresenter(
            item: item,
            organizationID: orgID,
            currentUserID: UUID(),
            isCurrentUserAdmin: false,
            service: ReservationsServiceListNoop(),
            organizationsService: ReservationsPresenterTestOrgService(),
            eventsService: events
        )
        sut.onAppear()
        #expect(sut.eventName(for: eventID) == "Фестиваль")
        #expect(sut.eventName(for: nil) == nil)
    }

    @Test
    func maxQuantityForDraft_prefersAvailabilityOverItemQuantity() {
        let item = Item(name: "x", categoryName: "c", quantity: 100)
        let svc = ReservationsServiceListNoop()
        svc.availabilitySnapshot = ItemAvailability(itemID: item.id, total: 50, reserved: 40, available: 10)
        let sut = ReservationsPresenter(
            item: item,
            organizationID: UUID(),
            currentUserID: UUID(),
            isCurrentUserAdmin: false,
            service: svc,
            organizationsService: ReservationsPresenterTestOrgService(),
            eventsService: ReservationsEventsNoop()
        )
        sut.onAppear()
        #expect(sut.maxQuantityForDraft == 10)
    }

    @Test
    func presentCreate_setsSheetAndInitialDraft() {
        let item = Item(name: "x", categoryName: "c", quantity: 20)
        let svc = ReservationsServiceListNoop()
        svc.availabilitySnapshot = ItemAvailability(itemID: item.id, total: 20, reserved: 5, available: 15)
        let sut = ReservationsPresenter(
            item: item,
            organizationID: UUID(),
            currentUserID: UUID(),
            isCurrentUserAdmin: false,
            service: svc,
            organizationsService: ReservationsPresenterTestOrgService(),
            eventsService: ReservationsEventsNoop()
        )
        sut.onAppear()
        sut.presentCreate()
        #expect(sut.isCreatePresented == true)
        #expect(sut.draftQuantity == 1)
        #expect(sut.draftEventID == nil)
        #expect(sut.draftHasExpiry == false)
    }

    private func makeSUT(currentUserID: UUID, isAdmin: Bool) -> ReservationsPresenter {
        let item = Item(name: "Тест", categoryName: "кат", quantity: 10)
        return ReservationsPresenter(
            item: item,
            organizationID: UUID(),
            currentUserID: currentUserID,
            isCurrentUserAdmin: isAdmin,
            service: ReservationsServiceListNoop(),
            organizationsService: ReservationsPresenterTestOrgService(),
            eventsService: ReservationsEventsNoop()
        )
    }

    private func makeReservation(reservedBy: UUID, status: ReservationStatus) -> ItemReservation {
        let now = Date()
        return ItemReservation(
            id: UUID(),
            itemID: UUID(),
            organizationID: UUID(),
            quantity: 1,
            eventID: nil,
            reservedByUserID: reservedBy,
            reservedAt: now,
            expiresAt: nil,
            status: status,
            fulfilledAt: nil,
            fulfilledByUserID: nil,
            cancelledAt: nil,
            cancelledByUserID: nil,
            cancellationReason: "",
            notes: "",
            createdAt: now,
            updatedAt: now
        )
    }
}

// MARK: - Test doubles

private final class ReservationsServiceListNoop: ReservationsServiceProtocol {
    var list: [ItemReservation] = []
    var availabilitySnapshot = ItemAvailability(itemID: UUID(), total: 0, reserved: 0, available: 0)

    func listByItem(
        itemID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    ) {
        completion(.success(list))
    }

    func listByOrganization(
        organizationID: UUID,
        status: ReservationStatus?,
        completion: @escaping (Result<[ItemReservation], ReservationsError>) -> Void
    ) {
        completion(.success([]))
    }

    func availability(itemID: UUID, completion: @escaping (Result<ItemAvailability, ReservationsError>) -> Void) {
        completion(.success(availabilitySnapshot))
    }

    func create(
        itemID: UUID,
        params: CreateReservationParams,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    ) {
        completion(.failure(.validation("test")))
    }

    func fulfill(reservationID: UUID, completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void) {
        completion(.failure(.validation("test")))
    }

    func cancel(
        reservationID: UUID,
        cancellationReason: String,
        completion: @escaping (Result<ItemReservation, ReservationsError>) -> Void
    ) {
        completion(.failure(.validation("test")))
    }
}

private final class ReservationsPresenterTestOrgService: OrganizationsServiceProtocol {
    var members: [OrganizationMember] = []

    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void) {
        completion(.success([]))
    }

    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        completion(.failure(.notFound))
    }

    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void) {
        completion(.success(members))
    }

    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func changeMemberRole(
        organizationID: UUID,
        userID: UUID,
        role: OrgRole,
        completion: @escaping (Result<Void, OrganizationsError>) -> Void
    ) {
        completion(.failure(.serverError("")))
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void) {
        completion(.success([]))
    }

    func createInvite(
        organizationID: UUID,
        expiresInDays: Int?,
        maxUses: Int?,
        completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void
    ) {
        completion(.failure(.serverError("")))
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        completion(.failure(.serverError("")))
    }
}

private final class ReservationsEventsNoop: EventsServiceProtocol {
    var events: [OrgEvent] = []

    func list(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void) {
        completion(.success(events))
    }

    func create(
        organizationID: UUID,
        name: String,
        description: String,
        startsAt: Date?,
        completion: @escaping (Result<OrgEvent, EventsError>) -> Void
    ) {
        completion(.failure(.serverError("")))
    }

    func update(id: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        completion(.failure(.serverError("")))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, EventsError>) -> Void) {
        completion(.failure(.serverError("")))
    }
}
