//
//  ActiveOrganizationStorageTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

struct ActiveOrganizationStorageTests {

    @Test
    func roundtrip_setClearActiveOrganizationID() throws {
        let suiteName = "test.cstatiWarehouse.ActiveOrganizationStorageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let sut = UserDefaultsActiveOrganizationStorage(defaults: defaults)
        let id = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!

        sut.setActive(id)
        #expect(sut.activeOrganizationID == id)

        sut.clear()
        #expect(sut.activeOrganizationID == nil)
    }
}
