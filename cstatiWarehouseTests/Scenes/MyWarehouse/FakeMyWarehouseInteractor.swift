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

    private(set) var loadActiveItemsCallCount: Int = 0
    private(set) var archiveCalls: [(UUID, Int, ArchiveReason, String)] = []
    private(set) var deleteCalls: [UUID] = []
    private(set) var externalChangeCalls: [(Item, Bool)] = []

    func loadActiveItems() {
        loadActiveItemsCallCount += 1
    }

    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String) {
        archiveCalls.append((id, quantity, reason, reasonDetail))
    }

    func deleteItem(id: UUID) {
        deleteCalls.append(id)
    }

    func applyExternalChange(_ item: Item, isNew: Bool) {
        externalChangeCalls.append((item, isNew))
        presenter?.itemChangedExternally(item, isNew: isNew)
    }
}
