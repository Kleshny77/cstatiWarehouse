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
    private(set) var archiveCalls: [(UUID, ArchiveReason, Date)] = []
    private(set) var deleteCalls: [UUID] = []
    private(set) var externalChangeCalls: [(Item, Bool)] = []
    
    func loadActiveItems() {
        loadActiveItemsCallCount += 1
    }
    
    func archiveItem(id: UUID, reason: ArchiveReason, at date: Date) {
        archiveCalls.append((id, reason, date))
    }
    
    func deleteItem(id: UUID) {
        deleteCalls.append(id)
    }
    
    func applyExternalChange(_ item: Item, isNew: Bool) {
        externalChangeCalls.append((item, isNew))
        presenter?.itemChangedExternally(item, isNew: isNew)
    }
}
