//
//  MyWarehouseInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol MyWarehouseInteractorInputProtocol: AnyObject {
    func loadActiveItems()
    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String)
    func deleteItem(id: UUID)
    func applyExternalChange(_ item: Item, isNew: Bool)
}

protocol MyWarehouseInteractorOutputProtocol: AnyObject {
    func itemsLoaded(_ items: [Item])
    func itemArchived(_ item: Item)
    func itemDeleted(id: UUID)
    func itemChangedExternally(_ item: Item, isNew: Bool)
    func failed(error: String)
}

final class MyWarehouseInteractor: MyWarehouseInteractorInputProtocol {
    weak var presenter: MyWarehouseInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol

    init(warehouseService: WarehouseServiceProtocol) {
        self.warehouseService = warehouseService
    }

    // MARK: Public Methods

    func loadActiveItems() {
        warehouseService.fetchActiveItems { [weak self] result in
            switch result {
            case .success(let items):
                self?.presenter?.itemsLoaded(items)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    func archiveItem(id: UUID, quantity: Int, reason: ArchiveReason, reasonDetail: String) {
        warehouseService.archiveItem(
            id: id,
            quantity: quantity,
            reason: reason,
            reasonDetail: reasonDetail
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
}
