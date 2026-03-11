//
//  CoordinatorView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

struct CoordinatorView: View {
  @State private var coordinator = AppCoordinator()
  
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
      MainView()
    case .register:
      RegisterAssembly.assemble(appCoordinator: coordinator)
    }
  }
}

struct MainView: View {
  var body: some View {
    Text("Main View")
      .navigationTitle("Главная")
  }
}
