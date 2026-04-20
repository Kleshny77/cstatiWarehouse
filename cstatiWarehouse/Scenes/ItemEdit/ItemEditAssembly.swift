//
//  ItemEditAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

final class ItemEditAssembly {
    static func assemble(
        mode: ItemEditMode,
        organizationID: UUID,
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol = AppServices.organizationsService(),
        orgCategoriesService: OrgCategoriesServiceProtocol = AppServices.orgCategoriesService(),
        uploadsService: UploadsServiceProtocol = AppServices.uploadsService(),
        sessionStorage: UserSessionStorageProtocol = AppServices.sessionStorage,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> some View {
        let currentUserID = sessionStorage.currentUser?.id.flatMap(UUID.init(uuidString:))
        let presenter = ItemEditPresenter(mode: mode, currentUserID: currentUserID, onFinish: onFinish)
        let interactor = ItemEditInteractor(
            warehouseService: warehouseService,
            organizationsService: organizationsService,
            orgCategoriesService: orgCategoriesService,
            uploadsService: uploadsService,
            organizationID: organizationID
        )
        let router = ItemEditRouter()

        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return ItemEditView(presenter: presenter)
            .onAppear {
                presenter.viewDidLoad()
            }
    }
}
