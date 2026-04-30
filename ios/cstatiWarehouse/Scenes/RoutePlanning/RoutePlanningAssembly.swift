//
//  RoutePlanningAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import SwiftUI

final class RoutePlanningAssembly {
    static func assemble(
        onDismiss: @escaping () -> Void,
        warehouseService: WarehouseServiceProtocol = AppServices.warehouseService(),
        activeOrgStorage: ActiveOrganizationStorageProtocol = AppServices.activeOrganizationStorage,
        geocoder: AddressGeocoderProtocol = AddressGeocoder(),
        routeAssembler: MultiLegDrivingRouteAssembler = MultiLegDrivingRouteAssembler(),
        eventsService: EventsServiceProtocol = AppServices.eventsService(),
        reservationsService: ReservationsServiceProtocol = AppServices.reservationsService()
    ) -> some View {
        let presenter = RoutePlanningPresenter(geocoder: geocoder)
        let interactor = RoutePlanningInteractor(
            warehouseService: warehouseService,
            activeOrgStorage: activeOrgStorage,
            geocoder: geocoder,
            routeAssembler: routeAssembler,
            eventsService: eventsService,
            reservationsService: reservationsService
        )
        let router = RoutePlanningRouter(onDismiss: onDismiss)

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return RoutePlanningView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
