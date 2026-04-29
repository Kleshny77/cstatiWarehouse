//
//  PickupRouteOrderingTests.swift
//  cstatiWarehouseTests
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
@testable import cstatiWarehouse
import XCTest

final class PickupRouteOrderingTests: XCTestCase {

    func testSinglePickupUnchanged() {
        let w = makeWaypoint(address: "Адрес А", lat: 55.75, lon: 37.62)
        let out = PickupRouteOrdering.orderPickups([w])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].id, w.id)
    }

    func testOrdersAlongNearestNeighborFromLexicographicSeed() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let a = makeWaypoint(id: idA, address: "Москва, точка А", lat: 55.750, lon: 37.600)
        let b = makeWaypoint(id: idB, address: "Москва, точка Б", lat: 55.751, lon: 37.600)
        let c = makeWaypoint(id: idC, address: "Москва, точка В", lat: 55.900, lon: 37.600)

        let out = PickupRouteOrdering.orderPickups([c, b, a])

        XCTAssertEqual(out.map(\.displayAddress), [
            "Москва, точка А",
            "Москва, точка Б",
            "Москва, точка В"
        ])
    }

    private func makeWaypoint(
        id: UUID = UUID(),
        address: String,
        lat: Double,
        lon: Double
    ) -> PickupWaypoint {
        PickupWaypoint(
            id: id,
            addressKey: address.lowercased(),
            displayAddress: address,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            lines: []
        )
    }
}
