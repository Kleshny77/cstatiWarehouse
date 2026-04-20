//
//  TabBarView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 01.02.2026.
//

import SwiftUI

struct TabBarView: View {
    let appCoordinator: AppCoordinatorProtocol

    var body: some View {
        TabView {
            Tab("Мой склад", systemImage: "shippingbox") {
                MyWarehouseAssembly.assemble(appCoordinator: appCoordinator)
            }
            Tab("Организация", systemImage: "person.2") {
                OrganizationAssembly.assemble(appCoordinator: appCoordinator)
            }
            Tab("Настройки", systemImage: "gearshape") {
                SettingsAssembly.assemble(appCoordinator: appCoordinator)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    TabBarView(appCoordinator: AppCoordinator())
}
