//
//  RoutePlanningPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct RoutePlanningPresenterTests {
    @Test
    func buildRouteTapped_withoutValidatedDestination_setsMessage() {
        let sut = RoutePlanningPresenter(geocoder: ImmediateGeocoder(), addressGeocodeDebounce: 0)
        sut.destinationAddress = ""

        sut.buildRouteTapped()

        #expect(sut.errorMessage == "Укажите адрес мероприятия.")
    }

    @Test
    func setQuantity_clampsToMax() {
        let sut = RoutePlanningPresenter(geocoder: ImmediateGeocoder(), addressGeocodeDebounce: 0)
        let id = UUID()
        sut.pickupItemsLoaded([
            RoutePlanningItemRow(id: id, name: "x", categoryName: "c", maxQuantity: 3, locationAddress: "А")
        ])

        sut.setQuantity(itemID: id, value: 99)
        #expect(sut.selection[id] == 3)

        sut.setQuantity(itemID: id, value: -5)
        #expect(sut.selection[id] == 0)
    }

    private final class ImmediateGeocoder: AddressGeocoderProtocol {
        func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, AddressGeocoderError>) -> Void) {
            DispatchQueue.main.async {
                completion(.success(CLLocationCoordinate2D(latitude: 1, longitude: 2)))
            }
        }
    }
}
