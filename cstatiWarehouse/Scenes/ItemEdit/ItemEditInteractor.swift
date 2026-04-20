//
//  ItemEditInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit

protocol ItemEditInteractorInputProtocol: AnyObject {
    func loadCategories()
    func save(item: Item, image: UIImage?, isNew: Bool)
}

protocol ItemEditInteractorOutputProtocol: AnyObject {
    func categoriesLoaded(_ categories: [String])
    func saved(_ item: Item)
    func failed(error: String)
}

final class ItemEditInteractor: ItemEditInteractorInputProtocol {
    weak var presenter: ItemEditInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol
    private let uploadsService: UploadsServiceProtocol
    private let organizationID: UUID

    init(
        warehouseService: WarehouseServiceProtocol,
        uploadsService: UploadsServiceProtocol,
        organizationID: UUID
    ) {
        self.warehouseService = warehouseService
        self.uploadsService = uploadsService
        self.organizationID = organizationID
    }

    // MARK: Public Methods

    func loadCategories() {
        warehouseService.fetchCategories(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let categories):
                self?.presenter?.categoriesLoaded(categories)
            case .failure:
                self?.presenter?.categoriesLoaded([])
            }
        }
    }

    func save(item: Item, image: UIImage?, isNew: Bool) {
        guard let image else {
            persist(item: item, isNew: isNew)
            return
        }
        uploadsService.uploadImage(image) { [weak self] result in
            switch result {
            case .success(let url):
                var updated = item
                updated.imageURL = url
                self?.persist(item: updated, isNew: isNew)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    // MARK: Private Methods

    private func persist(item: Item, isNew: Bool) {
        let completion: (Result<Item, WarehouseError>) -> Void = { [weak self] result in
            switch result {
            case .success(let saved):
                self?.presenter?.saved(saved)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }

        if isNew {
            warehouseService.createItem(item, organizationID: organizationID, completion: completion)
        } else {
            warehouseService.updateItem(item, completion: completion)
        }
    }
}
