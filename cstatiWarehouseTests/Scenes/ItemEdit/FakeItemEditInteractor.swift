//
//  FakeItemEditInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit
@testable import cstatiWarehouse

@MainActor
final class FakeItemEditInteractor: ItemEditInteractorInputProtocol {
    private(set) var loadCategoriesCallCount: Int = 0
    private(set) var saveCalls: [(Item, UIImage?, Bool)] = []
    
    func loadCategories() {
        loadCategoriesCallCount += 1
    }
    
    func save(item: Item, image: UIImage?, isNew: Bool) {
        saveCalls.append((item, image, isNew))
    }
}
