//
//  FakeItemEditInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
@testable import cstatiWarehouse

@MainActor
final class FakeItemEditInteractor: ItemEditInteractorInputProtocol {
    private(set) var saveCalls: [(Item, Bool)] = []
    
    func save(item: Item, isNew: Bool) {
        saveCalls.append((item, isNew))
    }
}
