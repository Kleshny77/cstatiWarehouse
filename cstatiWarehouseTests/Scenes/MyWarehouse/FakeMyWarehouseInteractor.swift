//
//  FakeMyWarehouseInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
@testable import cstatiWarehouse

@MainActor
final class FakeMyWarehouseInteractor: MyWarehouseInteractorInputProtocol {
    weak var presenter: MyWarehouseInteractorOutputProtocol?

    private(set) var resolveActiveOrganizationCallCount: Int = 0
    private(set) var loadActiveItemsCallCount: Int = 0
    private(set) var loadArchiveEventsCallCount: Int = 0
    private(set) var archiveCalls: [(UUID, Int, ArchiveReason, String, UUID?)] = []
    private(set) var deleteCalls: [UUID] = []
    private(set) var externalChangeCalls: [(Item, Bool)] = []

    func resolveActiveOrganization() {
        resolveActiveOrganizationCallCount += 1
    }

    func loadActiveItems(organizationID: UUID, scope: WarehouseScope) {
        loadActiveItemsCallCount += 1
    }

    func loadArchiveEvents(organizationID: UUID) {
        loadArchiveEventsCallCount += 1
    }

    func loadMyOrganizations() {}

    func selectActiveOrganization(_ id: UUID) {}

    func createOrganization(name: String) {}

    func joinOrganization(code: String) {}

    func prepareArchive(for item: Item) {
        presenter?.archiveReady(item: item, orgEvents: [])
    }

    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String, eventID: UUID?) {
        archiveCalls.append((id, quantity, reason, reasonDetail, eventID))
    }

    func deleteItem(id: UUID) {
        deleteCalls.append(id)
    }

    func applyExternalChange(_ item: Item, isNew: Bool) {
        externalChangeCalls.append((item, isNew))
        presenter?.itemChangedExternally(item, isNew: isNew)
    }
}
