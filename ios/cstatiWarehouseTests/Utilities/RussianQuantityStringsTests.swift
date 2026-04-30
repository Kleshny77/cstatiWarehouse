//
//  RussianQuantityStringsTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Testing
@testable import cstatiWarehouse

struct RussianQuantityStringsTests {

    @Test(arguments: [
        (1, "упаковка"),
        (2, "упаковки"),
        (4, "упаковки"),
        (5, "упаковок"),
        (11, "упаковок"),
        (21, "упаковка"),
        (22, "упаковки"),
        (24, "упаковки"),
        (25, "упаковок"),
    ])
    func packagingForm_matchesRussianPluralRules(count: Int, expected: String) {
        #expect(RussianQuantityStrings.packagingForm(for: count) == expected)
    }

    @Test
    func packagingPhrase_includesCount() {
        #expect(RussianQuantityStrings.packagingPhrase(count: 4) == "4 упаковки")
    }
}
