//
//  MyWarehouseInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol MyWarehouseInteractorInputProtocol: AnyObject {
    func resolveActiveOrganization()
    func loadActiveItems(organizationID: UUID, scope: WarehouseScope)
    func loadArchiveEvents(organizationID: UUID)
    func loadMyOrganizations()
    func selectActiveOrganization(_ id: UUID)
    func createOrganization(name: String)
    func joinOrganization(code: String)
    func prepareArchive(for item: Item)
    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?)
    func deleteItem(id: UUID)
    func applyExternalChange(_ item: Item, isNew: Bool)
}

protocol MyWarehouseInteractorOutputProtocol: AnyObject {
    func activeOrganizationResolved(_ summary: OrganizationSummary?)
    func organizationsLoaded(_ organizations: [OrganizationSummary])
    func organizationCreated(_ summary: OrganizationSummary)
    func organizationJoined(_ summary: OrganizationSummary)
    func itemsLoaded(_ items: [Item])
    func archiveReady(item: Item, orgEvents: [OrgEvent])
    func itemArchived(_ item: Item)
    func itemDeleted(id: UUID)
    func itemChangedExternally(_ item: Item, isNew: Bool)
    func archiveEventsLoaded(_ events: [ArchiveEvent])
    func archiveHistoryFailed(_ message: String)
    func failed(error: String)
    func organizationFailed(error: String)
}

final class MyWarehouseInteractor: MyWarehouseInteractorInputProtocol {

    // MARK: Properties

    weak var presenter: MyWarehouseInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol
    private let eventsService: EventsServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol

    // MARK: Lifecycle

    init(
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        eventsService: EventsServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol
    ) {
        self.warehouseService = warehouseService
        self.organizationsService = organizationsService
        self.eventsService = eventsService
        self.activeOrgStorage = activeOrgStorage
    }

    // MARK: Public Methods

    func resolveActiveOrganization() {
        organizationsService.fetchMyOrganizations { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let summaries):
                self.presenter?.organizationsLoaded(summaries)
                let resolved = self.pickActive(from: summaries)
                if let resolved {
                    self.activeOrgStorage.setActive(resolved.organization.id)
                } else {
                    self.activeOrgStorage.setActive(nil)
                }
                self.presenter?.activeOrganizationResolved(resolved)
            case .failure(let error):
                self.presenter?.failed(error: error.message)
            }
        }
    }

    func loadActiveItems(organizationID: UUID, scope: WarehouseScope) {
        warehouseService.fetchActiveItems(organizationID: organizationID, scope: scope) { [weak self] result in
            switch result {
            case .success(let items):
                self?.presenter?.itemsLoaded(items)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func loadArchiveEvents(organizationID: UUID) {
        warehouseService.fetchArchiveEvents(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let events):
                self?.presenter?.archiveEventsLoaded(events)
            case .failure(let error):
                self?.presenter?.archiveHistoryFailed(error.message)
            }
        }
    }

    func loadMyOrganizations() {
        organizationsService.fetchMyOrganizations { [weak self] result in
            switch result {
            case .success(let summaries):
                self?.presenter?.organizationsLoaded(summaries)
            case .failure(let error):
                self?.presenter?.organizationFailed(error: error.message)
            }
        }
    }

    func selectActiveOrganization(_ id: UUID) {
        activeOrgStorage.setActive(id)
    }

    func createOrganization(name: String) {
        organizationsService.createOrganization(name: name) { [weak self] result in
            switch result {
            case .success(let summary):
                self?.activeOrgStorage.setActive(summary.organization.id)
                self?.presenter?.organizationCreated(summary)
            case .failure(let error):
                self?.presenter?.organizationFailed(error: error.message)
            }
        }
    }

    func joinOrganization(code: String) {
        organizationsService.joinByCode(code) { [weak self] result in
            switch result {
            case .success(let summary):
                self?.activeOrgStorage.setActive(summary.organization.id)
                self?.presenter?.organizationJoined(summary)
            case .failure(let error):
                self?.presenter?.organizationFailed(error: error.message)
            }
        }
    }

    func prepareArchive(for item: Item) {
        guard let orgID = activeOrgStorage.activeOrganizationID else { return }
        eventsService.list(organizationID: orgID) { [weak self] result in
            let events: [OrgEvent]
            switch result {
            case .success(let list): events = list
            case .failure: events = []
            }
            self?.presenter?.archiveReady(item: item, orgEvents: events)
        }
    }

    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?) {
        warehouseService.archiveItem(
            id: id,
            quantity: quantity,
            reason: reason,
            reasonDetail: reasonDetail,
            eventID: eventID
        ) { [weak self] result in
            switch result {
            case .success(let archiveResult):
                self?.presenter?.itemArchived(archiveResult.item)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func deleteItem(id: UUID) {
        warehouseService.deleteItem(id: id) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.itemDeleted(id: id)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func applyExternalChange(_ item: Item, isNew: Bool) {
        presenter?.itemChangedExternally(item, isNew: isNew)
    }

    // MARK: Private Methods

    private func pickActive(from summaries: [OrganizationSummary]) -> OrganizationSummary? {
        guard !summaries.isEmpty else { return nil }
        if let stored = activeOrgStorage.activeOrganizationID,
           let match = summaries.first(where: { $0.organization.id == stored }) {
            return match
        }
        if let personal = summaries.first(where: { $0.organization.isPersonal }) {
            return personal
        }
        return summaries.first
    }
}
