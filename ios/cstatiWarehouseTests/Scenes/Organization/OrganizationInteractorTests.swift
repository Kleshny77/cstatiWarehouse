//
//  OrganizationInteractorTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct OrganizationInteractorTests {
    @Test
    func loadSummary_noActiveOrganization_callsPresenter() async {
        let presenter = OrgOutputSpy()
        let sut = OrganizationInteractor(
            organizationsService: OrganizationsServiceConfigurable(fetchOrganizationResult: .failure(.notFound)),
            eventsService: EventsServiceNoop(),
            categoriesService: OrgCategoriesServiceNoop(),
            activityService: ActivityServiceNoop(),
            sessionStorage: SessionWithUser(id: nil),
            activeOrgStorage: MutableOrgStorage(activeID: nil)
        )
        sut.presenter = presenter

        sut.loadSummary()
        await Task.yield()

        #expect(presenter.noActiveOrganizationCount == 1)
    }

    @Test
    func loadSummary_fetchOrganizationFails_reportsLoadSummaryFailed() async {
        let presenter = OrgOutputSpy()
        let orgs = OrganizationsServiceConfigurable(
            fetchOrganizationResult: .failure(.notFound)
        )
        let sut = OrganizationInteractor(
            organizationsService: orgs,
            eventsService: EventsServiceNoop(),
            categoriesService: OrgCategoriesServiceNoop(),
            activityService: ActivityServiceNoop(),
            sessionStorage: SessionWithUser(id: nil),
            activeOrgStorage: MutableOrgStorage(activeID: UUID())
        )
        sut.presenter = presenter

        sut.loadSummary()
        await drainMain()

        #expect(presenter.loadSummaryFailedMessage == OrganizationsError.notFound.message)
    }

    @Test
    func loadSummary_success_loadsMembers_andSummary() async {
        let orgID = UUID()
        let memberID = UUID()
        let summary = makeSummary(orgID: orgID, role: .member)
        let member = OrganizationMember(
            userID: memberID,
            organizationID: orgID,
            role: .member,
            joinedAt: .now,
            name: "Имя",
            lastName: "Фамилия",
            email: "m@m.co",
            avatarURL: nil
        )

        let presenter = OrgOutputSpy()
        let orgs = OrganizationsServiceConfigurable(
            fetchOrganizationResult: .success(summary),
            fetchMembersResult: .success([member])
        )
        let session = SessionWithUser(id: memberID.uuidString)
        let sut = OrganizationInteractor(
            organizationsService: orgs,
            eventsService: EventsServiceNoop(),
            categoriesService: OrgCategoriesServiceNoop(),
            activityService: ActivityServiceNoop(),
            sessionStorage: session,
            activeOrgStorage: MutableOrgStorage(activeID: orgID)
        )
        sut.presenter = presenter

        sut.loadSummary()
        await drainMain()

        #expect(presenter.summaryLoadedCalls.count == 1)
        let call = presenter.summaryLoadedCalls[0]
        #expect(call.summary.organization.id == orgID)
        #expect(call.members.count == 1)
        #expect(call.currentUserID == memberID)
        #expect(presenter.invitesLoadedCalls.isEmpty)
    }

    @Test
    func loadSummary_ownerLoadsInvites() async {
        let orgID = UUID()
        let summary = makeSummary(orgID: orgID, role: .owner)
        let invite = OrganizationInvite(
            id: UUID(),
            organizationID: orgID,
            code: "ABC",
            createdByID: UUID(),
            createdAt: .now,
            expiresAt: nil,
            maxUses: nil,
            usedCount: 0,
            revokedAt: nil,
            isActive: true
        )

        let presenter = OrgOutputSpy()
        let orgs = OrganizationsServiceConfigurable(
            fetchOrganizationResult: .success(summary),
            fetchMembersResult: .success([]),
            listInvitesResult: .success([invite])
        )
        let sut = OrganizationInteractor(
            organizationsService: orgs,
            eventsService: EventsServiceNoop(),
            categoriesService: OrgCategoriesServiceNoop(),
            activityService: ActivityServiceNoop(),
            sessionStorage: SessionWithUser(id: nil),
            activeOrgStorage: MutableOrgStorage(activeID: orgID)
        )
        sut.presenter = presenter

        sut.loadSummary()
        await drainMain()

        #expect(presenter.invitesLoadedCalls.count == 1)
        #expect(presenter.invitesLoadedCalls[0].count == 1)
    }

    private func drainMain() async {
        for _ in 0..<40 {
            await Task.yield()
        }
    }

    private func makeSummary(orgID: UUID, role: OrgRole) -> OrganizationSummary {
        let now = Date()
        let org = Organization(
            id: orgID,
            name: "Тест",
            ownerID: UUID(),
            isPersonal: false,
            createdAt: now,
            updatedAt: now
        )
        return OrganizationSummary(organization: org, role: role)
    }
}

// MARK: - Spies & stubs

private final class OrgOutputSpy: OrganizationInteractorOutputProtocol {
    var noActiveOrganizationCount = 0
    var loadSummaryFailedMessage: String?
    var summaryLoadedCalls: [(summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?)] = []
    var invitesLoadedCalls: [[OrganizationInvite]] = []

    func noActiveOrganization() {
        noActiveOrganizationCount += 1
    }

    func summaryLoaded(_ summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?) {
        summaryLoadedCalls.append((summary, members, currentUserID))
    }

    func didLeave() {}
    func didDelete() {}
    func didRename(_ summary: OrganizationSummary) {}

    func invitesLoaded(_ invites: [OrganizationInvite]) {
        invitesLoadedCalls.append(invites)
    }

    func inviteCreated(_ invite: OrganizationInvite) {}
    func memberRemoved(userID: UUID) {}
    func memberRoleChanged(userID: UUID, role: OrgRole) {}
    func ownershipTransferred() {}
    func eventsLoaded(_ events: [OrgEvent]) {}
    func categoriesLoaded(_ categories: [OrgCategory]) {}
    func activityLoaded(_ entries: [ActivityEntry]) {}

    func loadSummaryFailed(message: String) {
        loadSummaryFailedMessage = message
    }

    func failed(error: String) {}
}

private final class MutableOrgStorage: ActiveOrganizationStorageProtocol {
    var activeOrganizationID: UUID?

    init(activeID: UUID?) {
        activeOrganizationID = activeID
    }

    func setActive(_ id: UUID?) {
        activeOrganizationID = id
    }

    func clear() {
        activeOrganizationID = nil
    }
}

private final class SessionWithUser: UserSessionStorageProtocol {
    private let userIdString: String?

    init(id: String?) {
        userIdString = id
    }

    var currentUser: User? {
        guard let userIdString else { return nil }
        return User(id: userIdString, email: "u@u.u", name: "U")
    }

    var accessToken: String? { nil }
    var refreshToken: String? { nil }
    var isLoggedIn: Bool { false }

    func save(user: User, accessToken: String, refreshToken: String) {}
    func updateTokens(accessToken: String, refreshToken: String) {}
    func updateUser(_ user: User) {}
    func clear() {}
}

private final class OrganizationsServiceConfigurable: OrganizationsServiceProtocol {
    var fetchOrganizationResult: Result<OrganizationSummary, OrganizationsError>
    var fetchMembersResult: Result<[OrganizationMember], OrganizationsError>
    var listInvitesResult: Result<[OrganizationInvite], OrganizationsError>

    init(
        fetchOrganizationResult: Result<OrganizationSummary, OrganizationsError>,
        fetchMembersResult: Result<[OrganizationMember], OrganizationsError> = .success([]),
        listInvitesResult: Result<[OrganizationInvite], OrganizationsError> = .success([])
    ) {
        self.fetchOrganizationResult = fetchOrganizationResult
        self.fetchMembersResult = fetchMembersResult
        self.listInvitesResult = listInvitesResult
    }

    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(self.fetchOrganizationResult) }
    }

    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(self.fetchMembersResult) }
    }

    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func changeMemberRole(
        organizationID: UUID,
        userID: UUID,
        role: OrgRole,
        completion: @escaping (Result<Void, OrganizationsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(self.listInvitesResult) }
    }

    func createInvite(
        organizationID: UUID,
        expiresInDays: Int?,
        maxUses: Int?,
        completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }
}

private final class EventsServiceNoop: EventsServiceProtocol {
    func list(organizationID: UUID, completion: @escaping (Result<[OrgEvent], EventsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func create(
        organizationID: UUID,
        name: String,
        description: String,
        startsAt: Date?,
        completion: @escaping (Result<OrgEvent, EventsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func update(id: UUID, name: String, description: String, startsAt: Date?, completion: @escaping (Result<OrgEvent, EventsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, EventsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }
}

private final class OrgCategoriesServiceNoop: OrgCategoriesServiceProtocol {
    func list(organizationID: UUID, completion: @escaping (Result<[OrgCategory], OrgCategoriesError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func create(organizationID: UUID, name: String, completion: @escaping (Result<OrgCategory, OrgCategoriesError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, OrgCategoriesError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }
}

private final class ActivityServiceNoop: ActivityServiceProtocol {
    func list(organizationID: UUID, limit: Int?, completion: @escaping (Result<[ActivityEntry], ActivityError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }
}
