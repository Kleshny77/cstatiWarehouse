//
//  RoutePlanningRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

protocol RoutePlanningRouterProtocol: AnyObject {
    func dismiss()
}

final class RoutePlanningRouter: RoutePlanningRouterProtocol {

    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func dismiss() {
        onDismiss()
    }
}
