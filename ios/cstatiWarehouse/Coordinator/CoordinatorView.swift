//
//  CoordinatorView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct CoordinatorView: View {
    @State private var coordinator: AppCoordinator
    
    init(sessionStorage: UserSessionStorageProtocol = AppServices.sessionStorage) {
        let coord = AppCoordinator()
        if sessionStorage.isLoggedIn {
            coord.path.append(AppRoute.main)
        }
        _coordinator = State(initialValue: coord)
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LoginAssembly.assemble(appCoordinator: coordinator)
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .login:
            LoginAssembly.assemble(appCoordinator: coordinator)
        case .main:
            TabBarView(appCoordinator: coordinator)
        case .register:
            RegisterAssembly.assemble(appCoordinator: coordinator)
        case .profile:
            SettingsAssembly.assemble(appCoordinator: coordinator)
        }
    }
}

#Preview {
    CoordinatorView()
}
