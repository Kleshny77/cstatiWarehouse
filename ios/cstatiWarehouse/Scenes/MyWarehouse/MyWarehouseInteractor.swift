//
//  MyWarehouseInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol MyWarehouseInteractorInputProtocol: AnyObject {
    func resolveActiveOrganization()
    func loadOrganizationMembers(organizationID: UUID)
    func loadActiveItems(organizationID: UUID, scope: WarehouseScope)
    func loadArchiveEvents(organizationID: UUID)
    func loadMyOrganizations()
    func selectActiveOrganization(_ id: UUID)
    func createOrganization(name: String)
    func joinOrganization(code: String)
    func prepareArchive(for item: Item)
    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?, expectedUpdatedAt: Date)
    func deleteItem(id: UUID)
    func applyExternalChange(_ item: Item, isNew: Bool)
}

protocol MyWarehouseInteractorOutputProtocol: AnyObject {
    func activeOrganizationResolved(_ summary: OrganizationSummary?)
    func organizationsLoaded(_ organizations: [OrganizationSummary])
    func organizationCreated(_ summary: OrganizationSummary)
    func organizationJoined(_ summary: OrganizationSummary)
    func itemsLoaded(_ items: [Item], scope: WarehouseScope)
    func archiveReady(item: Item, orgEvents: [OrgEvent])
    func itemArchived(_ item: Item)
    func itemDeleted(id: UUID)
    func itemChangedExternally(_ item: Item, isNew: Bool)
    func archiveEventsLoaded(_ events: [ArchiveEvent])
    func archiveHistoryFailed(_ message: String)
    func membersLoaded(_ members: [OrganizationMember])
    func initialLoadFailed(message: String)
    func itemsLoadFailed(message: String, scope: WarehouseScope)
    func failed(error: String)
    func organizationFailed(error: String)
    func joinAlreadyInOrganization()
    func warehouseActiveItemsCacheMissed(scope: WarehouseScope)
}

final class MyWarehouseInteractor: MyWarehouseInteractorInputProtocol {


    weak var presenter: MyWarehouseInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol
    private let eventsService: EventsServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol
    private let offlineCache: OfflineCacheStoreProtocol
    private let webSocketService: WebSocketService


    init(
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        eventsService: EventsServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol,
        offlineCache: OfflineCacheStoreProtocol = AppServices.offlineCache,
        webSocketService: WebSocketService = AppServices.webSocketService
    ) {
        self.warehouseService = warehouseService
        self.organizationsService = organizationsService
        self.eventsService = eventsService
        self.activeOrgStorage = activeOrgStorage
        self.offlineCache = offlineCache
        self.webSocketService = webSocketService
        
        self.webSocketService.eventHandler = self
    }
    
    deinit {
        webSocketService.disconnect()
    }


    func resolveActiveOrganization() {
        organizationsService.fetchMyOrganizations { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let summaries):
                self.presenter?.organizationsLoaded(summaries)
                let resolved = self.pickActive(from: summaries)
                if let resolved {
                    self.webSocketService.connect(organizationID: resolved.id)
                    self.activeOrgStorage.setActive(resolved.organization.id)
                } else {
                    self.activeOrgStorage.setActive(nil)
                }
                self.presenter?.activeOrganizationResolved(resolved)
            case .failure(let error):
                self.presenter?.initialLoadFailed(message: error.message)
            }
        }
    }

    func loadOrganizationMembers(organizationID: UUID) {
        organizationsService.fetchMembers(organizationID: organizationID) { [weak self] result in
            let members: [OrganizationMember]
            switch result {
            case .success(let list):
                members = list
            case .failure:
                members = []
            }
            DispatchQueue.main.async {
                self?.presenter?.membersLoaded(members)
            }
        }
    }

    func loadActiveItems(organizationID: UUID, scope: WarehouseScope) {
        let cacheKey = OfflineCacheKeys.warehouseActiveItems(organizationID: organizationID, scope: scope)
        Task { [weak self] in
            guard let self else { return }
            if let data = await self.offlineCache.payload(forKey: cacheKey),
               let items = try? WarehouseItemsCacheCodec.decodeItems(from: data) {
                await MainActor.run {
                    self.presenter?.itemsLoaded(items, scope: scope)
                }
            } else {
                await MainActor.run {
                    self.presenter?.warehouseActiveItemsCacheMissed(scope: scope)
                }
            }
            self.warehouseService.fetchActiveItems(organizationID: organizationID, scope: scope) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let items):
                    Task {
                        if let payload = try? WarehouseItemsCacheCodec.encodeItems(items) {
                            try? await self.offlineCache.save(payload: payload, forKey: cacheKey)
                        }
                    }
                    DispatchQueue.main.async {
                        self.presenter?.itemsLoaded(items, scope: scope)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.presenter?.itemsLoadFailed(message: error.message, scope: scope)
                    }
                }
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
        webSocketService.connect(organizationID: id)
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
                if case .alreadyMember = error {
                    self?.presenter?.joinAlreadyInOrganization()
                } else {
                    self?.presenter?.organizationFailed(error: error.message)
                }
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

    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?, expectedUpdatedAt: Date) {
        warehouseService.archiveItem(
            id: id,
            quantity: quantity,
            reason: reason,
            reasonDetail: reasonDetail,
            eventID: eventID,
            expectedUpdatedAt: expectedUpdatedAt
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

// MARK: - WebSocketEventHandler
extension MyWarehouseInteractor: WebSocketEventHandler {
    
    func handleItemCreated(_ item: Item) {
        print("[WebSocket] Item created: \(item.name)")
        presenter?.itemChangedExternally(item, isNew: true)
    }
    
    func handleItemUpdated(_ item: Item) {
        print("[WebSocket] Item updated: \(item.name)")
        presenter?.itemChangedExternally(item, isNew: false)
    }
    
    func handleItemArchived(_ item: Item) {
        print("[WebSocket] Item archived: \(item.name)")
        presenter?.itemChangedExternally(item, isNew: false)
    }
    
    func handleItemDeleted(itemID: UUID) {
        print("[WebSocket] Item deleted: \(itemID)")
        presenter?.itemDeleted(id: itemID)
    }
}
