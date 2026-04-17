//
//  ItemEditInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol ItemEditInteractorInputProtocol: AnyObject {
    func save(item: Item, isNew: Bool)
}

protocol ItemEditInteractorOutputProtocol: AnyObject {
    func saved(_ item: Item)
    func failed(error: String)
}

final class ItemEditInteractor: ItemEditInteractorInputProtocol {
    weak var presenter: ItemEditInteractorOutputProtocol?
    
    private let warehouseService: WarehouseServiceProtocol
    
    init(warehouseService: WarehouseServiceProtocol) {
        self.warehouseService = warehouseService
    }
    
    // MARK: Public Methods
    
    func save(item: Item, isNew: Bool) {
        let completion: (Result<Item, WarehouseError>) -> Void = { [weak self] result in
            switch result {
            case .success(let saved):
                self?.presenter?.saved(saved)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
        
        if isNew {
            warehouseService.createItem(item, completion: completion)
        } else {
            warehouseService.updateItem(item, completion: completion)
        }
    }
}
