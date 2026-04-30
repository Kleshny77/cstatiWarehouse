//
//  APIClientDateParsingTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

struct APIClientDateParsingTests {
    @Test
    func iso8601Fractional_parsesCommonBackendTimestamps() {
        let s1 = "2026-04-30T12:34:56.789Z"
        let d1 = APIClient.iso8601Fractional.date(from: s1)
        #expect(d1 != nil)

        let s2 = "2026-04-30T12:34:56Z"
        let d2 = APIClient.iso8601Basic.date(from: s2)
        #expect(d2 != nil)
    }

    @Test
    func garbageStrings_doNotParseAsDates() {
        #expect(APIClient.iso8601Fractional.date(from: "not-a-date") == nil)
        #expect(APIClient.iso8601Basic.date(from: "") == nil)
    }
}
