//
//  OrganizationPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct OrganizationPresenterTests {
    @Test
    func refresh_setsLoading_andCallsInteractor() {
        let interactor = OrgPresenterInteractorSpy()
        let sut = OrganizationPresenter()
        sut.interactor = interactor

        sut.refresh()

        #expect(sut.isLoading == true)
        #expect(interactor.loadSummaryCount == 1)
    }

    @Test
    func leaveRequested_personalOrganization_setsError() {
        let sut = OrganizationPresenter()
        let now = Date()
        let org = Organization(
            id: UUID(),
            name: "Личное",
            ownerID: UUID(),
            isPersonal: true,
            createdAt: now,
            updatedAt: now
        )
        sut.summaryLoaded(
            OrganizationSummary(organization: org, role: .member),
            members: [],
            currentUserID: nil
        )

        sut.leaveRequested()

        #expect(sut.errorMessage == "Нельзя выйти из персональной организации")
    }

    @Test
    func submitRename_blank_setsError() {
        let sut = OrganizationPresenter()
        let now = Date()
        let org = Organization(
            id: UUID(),
            name: "Компания",
            ownerID: UUID(),
            isPersonal: false,
            createdAt: now,
            updatedAt: now
        )
        sut.summaryLoaded(
            OrganizationSummary(organization: org, role: .owner),
            members: [],
            currentUserID: nil
        )

        sut.submitRename("   ")

        #expect(sut.errorMessage == "Введите название")
    }

    @Test
    func deleteRequested_nonOwner_setsError() {
        let sut = OrganizationPresenter()
        let now = Date()
        let org = Organization(
            id: UUID(),
            name: "Компания",
            ownerID: UUID(),
            isPersonal: false,
            createdAt: now,
            updatedAt: now
        )
        sut.summaryLoaded(
            OrganizationSummary(organization: org, role: .member),
            members: [],
            currentUserID: nil
        )

        sut.deleteRequested()

        #expect(sut.errorMessage == "Удалить может только владелец")
    }
}

private final class OrgPresenterInteractorSpy: OrganizationInteractorInputProtocol {
    var loadSummaryCount = 0

    func loadSummary() { loadSummaryCount += 1 }
    func leave(organizationID: UUID) {}
    func deleteOrganization(organizationID: UUID) {}
    func rename(organizationID: UUID, newName: String) {}
    func removeMember(organizationID: UUID, userID: UUID) {}
    func changeRole(organizationID: UUID, userID: UUID, role: OrgRole) {}
    func transferOwnership(organizationID: UUID, newOwnerID: UUID) {}
    func loadInvites(organizationID: UUID) {}
    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?) {}
    func revokeInvite(organizationID: UUID, inviteID: UUID) {}
    func loadEvents(organizationID: UUID) {}
    func createEvent(organizationID: UUID, name: String, description: String, startsAt: Date?) {}
    func deleteEvent(id: UUID, organizationID: UUID) {}
    func loadCategories(organizationID: UUID) {}
    func createCategory(organizationID: UUID, name: String) {}
    func deleteCategory(id: UUID, organizationID: UUID) {}
    func loadActivity(organizationID: UUID) {}
}
