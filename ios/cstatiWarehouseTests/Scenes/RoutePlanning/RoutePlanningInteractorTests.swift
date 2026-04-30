//
//  RoutePlanningInteractorTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct RoutePlanningInteractorTests {
    @Test
    func loadPickupItems_noActiveOrganization_reportsFailure() async {
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: MockWarehouseService(seed: []),
            activeOrgStorage: MutableActiveOrgStorage(activeID: nil),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy

        sut.loadPickupItems()
        await drainMain()

        #expect(spy.failureMessage == "Нет активной организации.")
        #expect(spy.loadedRows == nil)
    }

    @Test
    func loadPickupItems_success_returnsSortedRows() async {
        let orgID = MockWarehouseService.defaultOrganizationID
        let a = makeRootItem(name: "банан", locationAddress: "Москва, Б")
        let b = makeRootItem(name: "абрикос", locationAddress: "Москва, А")
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: MockWarehouseService(seed: [a, b]),
            activeOrgStorage: MutableActiveOrgStorage(activeID: orgID),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy

        sut.loadPickupItems()
        await drainMain()

        #expect(spy.failureMessage == nil)
        let names = spy.loadedRows?.map(\.name) ?? []
        #expect(names == ["абрикос", "банан"])
    }

    @Test
    func loadPickupItems_warehouseFailure_reportsMessage() async {
        let orgID = MockWarehouseService.defaultOrganizationID
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: WarehouseFetchFailureStub(),
            activeOrgStorage: MutableActiveOrgStorage(activeID: orgID),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy

        sut.loadPickupItems()
        await drainMain()

        #expect(spy.failureMessage == WarehouseError.networkError(nil).message)
    }

    @Test
    func buildRoute_emptyDestination_reportsFailure() {
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: MockWarehouseService(seed: []),
            activeOrgStorage: MutableActiveOrgStorage(activeID: MockWarehouseService.defaultOrganizationID),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy
        sut.buildRoute(
            selection: [:],
            destinationAddress: "   ",
            startAddress: nil,
            transport: .automobile
        )
        #expect(spy.failureMessage == "Укажите адрес мероприятия.")
    }

    @Test
    func buildRoute_emptySelection_reportsFailure() {
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: MockWarehouseService(seed: []),
            activeOrgStorage: MutableActiveOrgStorage(activeID: MockWarehouseService.defaultOrganizationID),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy
        sut.buildRoute(
            selection: [:],
            destinationAddress: "Москва",
            startAddress: nil,
            transport: .automobile
        )
        #expect(spy.failureMessage == "Выберите хотя бы одну позицию и количество.")
    }

    @Test
    func buildRoute_missingStorageAddress_reportsFailure() async {
        let orgID = MockWarehouseService.defaultOrganizationID
        let item = makeRootItem(name: "Без адреса", locationAddress: "")
        let spy = RoutePlanningPresenterSpy()
        let sut = RoutePlanningInteractor(
            warehouseService: MockWarehouseService(seed: [item]),
            activeOrgStorage: MutableActiveOrgStorage(activeID: orgID),
            geocoder: StubGeocoder(),
            routeAssembler: MultiLegDrivingRouteAssembler()
        )
        sut.presenter = spy

        sut.loadPickupItems()
        await drainMain()

        sut.buildRoute(
            selection: [item.id: 1],
            destinationAddress: "Москва, Центр",
            startAddress: nil,
            transport: .automobile
        )

        #expect(spy.failureMessage?.contains("Без адреса") == true)
    }

    // MARK: - Helpers

    private func drainMain() async {
        for _ in 0..<80 {
            await Task.yield()
        }
    }

    private func makeRootItem(name: String, locationAddress: String) -> Item {
        Item(
            name: name,
            categoryName: "кат",
            quantity: 3,
            locationAddress: locationAddress
        )
    }

    private final class RoutePlanningPresenterSpy: RoutePlanningInteractorOutputProtocol {
        var failureMessage: String?
        var loadedRows: [RoutePlanningItemRow]?

        func pickupItemsLoaded(_ rows: [RoutePlanningItemRow]) {
            loadedRows = rows
        }

        func routePlanningFailed(message: String) {
            failureMessage = message
        }

        func routePlanningBuilt(model: RoutePlanningMapModel) {}

        func eventsLoaded(_ events: [OrgEvent]) {}

        func eventReservationsApplied(selection: [UUID: Int], skippedNames: [String]) {}
    }

    private final class MutableActiveOrgStorage: ActiveOrganizationStorageProtocol {
        var activeOrganizationID: UUID?

        init(activeID: UUID?) {
            activeOrganizationID = activeID
        }

        func setActive(_ id: UUID?) {
            activeOrganizationID = id
        }

        func clear() {
            activeOrganizationID = nil
        }
    }

    private final class StubGeocoder: AddressGeocoderProtocol {
        func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, AddressGeocoderError>) -> Void) {
            DispatchQueue.main.async {
                completion(.success(CLLocationCoordinate2D(latitude: 55.75, longitude: 37.62)))
            }
        }
    }

    private final class WarehouseFetchFailureStub: WarehouseServiceProtocol {
        func fetchActiveItems(
            organizationID: UUID,
            scope: WarehouseScope,
            completion: @escaping (Result<[Item], WarehouseError>) -> Void
        ) {
            DispatchQueue.main.async {
                completion(.failure(.networkError(nil)))
            }
        }

        func fetchHistory(organizationID: UUID, completion: @escaping (Result<[Item], WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.success([])) }
        }

        func fetchArchiveEvents(organizationID: UUID, completion: @escaping (Result<[ArchiveEvent], WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.success([])) }
        }

        func fetchCategories(organizationID: UUID, completion: @escaping (Result<[String], WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.success([])) }
        }

        func createItem(_ item: Item, organizationID: UUID, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.failure(.notFound)) }
        }

        func updateItem(_ item: Item, completion: @escaping (Result<Item, WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.failure(.notFound)) }
        }

        func archiveItem(
            id: UUID,
            quantity: Int,
            reason: ArchiveReason,
            reasonDetail: String,
            eventID: UUID?,
            expectedUpdatedAt: Date,
            completion: @escaping (Result<ArchiveResult, WarehouseError>) -> Void
        ) {
            DispatchQueue.main.async { completion(.failure(.notFound)) }
        }

        func deleteItem(id: UUID, completion: @escaping (Result<Void, WarehouseError>) -> Void) {
            DispatchQueue.main.async { completion(.failure(.notFound)) }
        }
    }
}
