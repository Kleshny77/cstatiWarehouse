//
// OrganizationInteractor.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

protocol OrganizationInteractorInputProtocol: AnyObject {
    func loadSummary()
    func leave(organizationID: UUID)
    func deleteOrganization(organizationID: UUID)
    func rename(organizationID: UUID, newName: String)
    func removeMember(organizationID: UUID, userID: UUID)
    func changeRole(organizationID: UUID, userID: UUID, role: OrgRole)
    func transferOwnership(organizationID: UUID, newOwnerID: UUID)
    func loadInvites(organizationID: UUID)
    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?)
    func revokeInvite(organizationID: UUID, inviteID: UUID)

    // MARK: Events
    func loadEvents(organizationID: UUID)
    func createEvent(organizationID: UUID, name: String, description: String, startsAt: Date?)
    func deleteEvent(id: UUID, organizationID: UUID)

    // MARK: Categories
    func loadCategories(organizationID: UUID)
    func createCategory(organizationID: UUID, name: String)
    func deleteCategory(id: UUID, organizationID: UUID)

    // MARK: Activity
    func loadActivity(organizationID: UUID)
}

protocol OrganizationInteractorOutputProtocol: AnyObject {
    func noActiveOrganization()
    func summaryLoaded(_ summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?)
    func didLeave()
    func didDelete()
    func didRename(_ summary: OrganizationSummary)
    func invitesLoaded(_ invites: [OrganizationInvite])
    func inviteCreated(_ invite: OrganizationInvite)
    func memberRemoved(userID: UUID)
    func memberRoleChanged(userID: UUID, role: OrgRole)
    func ownershipTransferred()
    func eventsLoaded(_ events: [OrgEvent])
    func categoriesLoaded(_ categories: [OrgCategory])
    func activityLoaded(_ entries: [ActivityEntry])
    func failed(error: String)
}

final class OrganizationInteractor: OrganizationInteractorInputProtocol {

    // MARK: Properties

    weak var presenter: OrganizationInteractorOutputProtocol?

    private let organizationsService: OrganizationsServiceProtocol
    private let eventsService: EventsServiceProtocol
    private let categoriesService: OrgCategoriesServiceProtocol
    private let activityService: ActivityServiceProtocol
    private let sessionStorage: UserSessionStorageProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol

    // MARK: Lifecycle

    init(
        organizationsService: OrganizationsServiceProtocol,
        eventsService: EventsServiceProtocol,
        categoriesService: OrgCategoriesServiceProtocol,
        activityService: ActivityServiceProtocol,
        sessionStorage: UserSessionStorageProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol
    ) {
        self.organizationsService = organizationsService
        self.eventsService = eventsService
        self.categoriesService = categoriesService
        self.activityService = activityService
        self.sessionStorage = sessionStorage
        self.activeOrgStorage = activeOrgStorage
    }

    // MARK: Public Methods

    func loadSummary() {
        guard let activeID = activeOrgStorage.activeOrganizationID else {
            presenter?.noActiveOrganization()
            return
        }
        organizationsService.fetchOrganization(id: activeID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let summary):
                self.loadMembers(for: summary)
            case .failure(let error):
                self.presenter?.failed(error: error.message)
            }
        }
    }

    func leave(organizationID: UUID) {
        organizationsService.leaveOrganization(id: organizationID) { [weak self] result in
            switch result {
            case .success:
                self?.activeOrgStorage.setActive(nil)
                self?.presenter?.didLeave()
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func deleteOrganization(organizationID: UUID) {
        organizationsService.deleteOrganization(id: organizationID) { [weak self] result in
            switch result {
            case .success:
                self?.activeOrgStorage.setActive(nil)
                self?.presenter?.didDelete()
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func rename(organizationID: UUID, newName: String) {
        organizationsService.updateOrganization(id: organizationID, name: newName) { [weak self] result in
            switch result {
            case .success(let summary):
                self?.presenter?.didRename(summary)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func removeMember(organizationID: UUID, userID: UUID) {
        organizationsService.removeMember(organizationID: organizationID, userID: userID) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.memberRemoved(userID: userID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func changeRole(organizationID: UUID, userID: UUID, role: OrgRole) {
        organizationsService.changeMemberRole(organizationID: organizationID, userID: userID, role: role) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.memberRoleChanged(userID: userID, role: role)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID) {
        organizationsService.transferOwnership(organizationID: organizationID, newOwnerID: newOwnerID) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.ownershipTransferred()
                self?.loadSummary()
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func loadInvites(organizationID: UUID) {
        organizationsService.listInvites(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let invites):
                self?.presenter?.invitesLoaded(invites)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func createInvite(organizationID: UUID, expiresInDays: Int?, maxUses: Int?) {
        organizationsService.createInvite(
            organizationID: organizationID,
            expiresInDays: expiresInDays,
            maxUses: maxUses
        ) { [weak self] result in
            switch result {
            case .success(let invite):
                self?.presenter?.inviteCreated(invite)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID) {
        organizationsService.revokeInvite(organizationID: organizationID, inviteID: inviteID) { [weak self] result in
            switch result {
            case .success:
                self?.loadInvites(organizationID: organizationID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func loadEvents(organizationID: UUID) {
        eventsService.list(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let events):
                self?.presenter?.eventsLoaded(events)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func createEvent(organizationID: UUID, name: String, description: String, startsAt: Date?) {
        eventsService.create(
            organizationID: organizationID,
            name: name,
            description: description,
            startsAt: startsAt
        ) { [weak self] result in
            switch result {
            case .success:
                self?.loadEvents(organizationID: organizationID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func deleteEvent(id: UUID, organizationID: UUID) {
        eventsService.delete(id: id) { [weak self] result in
            switch result {
            case .success:
                self?.loadEvents(organizationID: organizationID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func loadCategories(organizationID: UUID) {
        categoriesService.list(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let cats):
                self?.presenter?.categoriesLoaded(cats)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func createCategory(organizationID: UUID, name: String) {
        categoriesService.create(organizationID: organizationID, name: name) { [weak self] result in
            switch result {
            case .success:
                self?.loadCategories(organizationID: organizationID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func deleteCategory(id: UUID, organizationID: UUID) {
        categoriesService.delete(id: id) { [weak self] result in
            switch result {
            case .success:
                self?.loadCategories(organizationID: organizationID)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func loadActivity(organizationID: UUID) {
        activityService.list(organizationID: organizationID, limit: 100) { [weak self] result in
            switch result {
            case .success(let entries):
                self?.presenter?.activityLoaded(entries)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    // MARK: Private Methods

    private func loadMembers(for summary: OrganizationSummary) {
        organizationsService.fetchMembers(organizationID: summary.organization.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let members):
                let currentID = self.currentUserUUID()
                self.presenter?.summaryLoaded(summary, members: members, currentUserID: currentID)
                if summary.role.canManageMembers {
                    self.loadInvites(organizationID: summary.organization.id)
                }
            case .failure(let error):
                self.presenter?.failed(error: error.message)
            }
        }
    }

    private func currentUserUUID() -> UUID? {
        guard let raw = sessionStorage.currentUser?.id else { return nil }
        return UUID(uuidString: raw)
    }
}
