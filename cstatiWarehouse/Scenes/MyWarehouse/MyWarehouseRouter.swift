//
//  MyWarehouseRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import SwiftUI

protocol MyWarehouseRouterProtocol: AnyObject {
    func navigateToProfile()
    func makeItemEditScene(
        mode: ItemEditMode,
        organizationID: UUID,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> AnyView
}

final class MyWarehouseRouter: MyWarehouseRouterProtocol {
    // MARK: Properties
    
    private weak var appCoordinator: AppCoordinatorProtocol?
    private let warehouseService: WarehouseServiceProtocol
    
    init(appCoordinator: AppCoordinatorProtocol, warehouseService: WarehouseServiceProtocol) {
        self.appCoordinator = appCoordinator
        self.warehouseService = warehouseService
    }
    
    // MARK: Public Methods
    
    func navigateToProfile() {
        appCoordinator?.navigate(to: .profile)
    }
    
    func makeItemEditScene(
        mode: ItemEditMode,
        organizationID: UUID,
        onFinish: @escaping (ItemEditResult) -> Void
    ) -> AnyView {
        AnyView(
            ItemEditAssembly.assemble(
                mode: mode,
                organizationID: organizationID,
                warehouseService: warehouseService,
                onFinish: onFinish
            )
        )
    }
}
