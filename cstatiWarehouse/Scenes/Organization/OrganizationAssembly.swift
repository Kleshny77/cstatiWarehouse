//
// OrganizationAssembly.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import SwiftUI

final class OrganizationAssembly {
    static func assemble(
        appCoordinator: AppCoordinatorProtocol,
        organizationsService: OrganizationsServiceProtocol = AppServices.organizationsService(),
        eventsService: EventsServiceProtocol = AppServices.eventsService(),
        categoriesService: OrgCategoriesServiceProtocol = AppServices.orgCategoriesService(),
        activityService: ActivityServiceProtocol = AppServices.activityService(),
        sessionStorage: UserSessionStorageProtocol = AppServices.sessionStorage,
        activeOrgStorage: ActiveOrganizationStorageProtocol = AppServices.activeOrganizationStorage
    ) -> some View {
        let presenter = OrganizationPresenter()
        let interactor = OrganizationInteractor(
            organizationsService: organizationsService,
            eventsService: eventsService,
            categoriesService: categoriesService,
            activityService: activityService,
            sessionStorage: sessionStorage,
            activeOrgStorage: activeOrgStorage
        )
        let router = OrganizationRouter(appCoordinator: appCoordinator)

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return OrganizationView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
