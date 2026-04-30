//
//  ShelfRiskBandTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import Testing
@testable import cstatiWarehouse

struct ShelfRiskBandTests {

    @Test
    func titles_areNonEmptyRussian() {
        for band in ShelfRiskBand.allCases {
            #expect(!band.title.isEmpty)
            #expect(!band.chartAxisLabel.isEmpty)
        }
    }

    @Test
    func ids_matchRawValues() {
        for band in ShelfRiskBand.allCases {
            #expect(band.id == band.rawValue)
        }
    }
}
