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
}

protocol OrganizationInteractorOutputProtocol: AnyObject {
    func noActiveOrganization()
    func summaryLoaded(_ summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?)
    func didLeave()
    func didDelete()
    func didRename(_ summary: OrganizationSummary)
    func failed(error: String)
}

final class OrganizationInteractor: OrganizationInteractorInputProtocol {

    // MARK: Properties

    weak var presenter: OrganizationInteractorOutputProtocol?

    private let organizationsService: OrganizationsServiceProtocol
    private let sessionStorage: UserSessionStorageProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol

    // MARK: Lifecycle

    init(
        organizationsService: OrganizationsServiceProtocol,
        sessionStorage: UserSessionStorageProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol
    ) {
        self.organizationsService = organizationsService
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

    // MARK: Private Methods

    private func loadMembers(for summary: OrganizationSummary) {
        organizationsService.fetchMembers(organizationID: summary.organization.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let members):
                let currentID = self.currentUserUUID()
                self.presenter?.summaryLoaded(summary, members: members, currentUserID: currentID)
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
