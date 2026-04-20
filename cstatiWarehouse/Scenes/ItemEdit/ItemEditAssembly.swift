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
        uploadsService: UploadsServiceProtocol = AppServices.uploadsService(),
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> some View {
        let presenter = ItemEditPresenter(mode: mode, onFinish: onFinish)
        let interactor = ItemEditInteractor(
            warehouseService: warehouseService,
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
