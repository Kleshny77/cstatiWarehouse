//
//  ItemEditAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

// MARK: - ItemEditAssembly

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
    ) -> ItemEditHostedScene {
        ItemEditHostedScene(
            mode: mode,
            organizationID: organizationID,
            warehouseService: warehouseService,
            organizationsService: organizationsService,
            orgCategoriesService: orgCategoriesService,
            uploadsService: uploadsService,
            sessionStorage: sessionStorage,
            onFinish: onFinish
        )
    }

    fileprivate static func buildPresenter(
        mode: ItemEditMode,
        organizationID: UUID,
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        orgCategoriesService: OrgCategoriesServiceProtocol,
        uploadsService: UploadsServiceProtocol,
        sessionStorage: UserSessionStorageProtocol,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> ItemEditPresenter {
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
        return presenter
    }
}

// MARK: - ItemEditHostedScene

struct ItemEditHostedScene: View {
    let mode: ItemEditMode
    let organizationID: UUID
    let warehouseService: WarehouseServiceProtocol
    let organizationsService: OrganizationsServiceProtocol
    let orgCategoriesService: OrgCategoriesServiceProtocol
    let uploadsService: UploadsServiceProtocol
    let sessionStorage: UserSessionStorageProtocol
    let onFinish: (ItemEditResult) -> Void

    @State private var presenter: ItemEditPresenter?

    var body: some View {
        Group {
            if let presenter {
                ItemEditView(presenter: presenter)
            } else {
                ZStack {
                    GradientBackground()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .onAppear {
            guard presenter == nil else { return }
            let p = ItemEditAssembly.buildPresenter(
                mode: mode,
                organizationID: organizationID,
                warehouseService: warehouseService,
                organizationsService: organizationsService,
                orgCategoriesService: orgCategoriesService,
                uploadsService: uploadsService,
                sessionStorage: sessionStorage,
                onFinish: onFinish
            )
            presenter = p
            p.viewDidLoad()
        }
    }
}
