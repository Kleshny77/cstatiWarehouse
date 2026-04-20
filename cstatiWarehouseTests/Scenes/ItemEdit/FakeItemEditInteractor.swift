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
    private(set) var loadMembersCallCount: Int = 0
    private(set) var createOrgCategoryCalls: [String] = []
    private(set) var saveCalls: [(Item, UIImage?, Bool)] = []

    func loadCategories() {
        loadCategoriesCallCount += 1
    }

    func loadMembers() {
        loadMembersCallCount += 1
    }

    func createOrgCategory(name: String) {
        createOrgCategoryCalls.append(name)
    }

    func save(item: Item, image: UIImage?, isNew: Bool) {
        saveCalls.append((item, image, isNew))
    }
}
