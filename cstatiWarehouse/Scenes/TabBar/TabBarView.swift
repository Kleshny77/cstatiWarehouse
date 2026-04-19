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
            Tab("Организация", systemImage: "cancel") {
                MockView()
            }
            Tab("Настройки", systemImage: "pencil") {
                MockView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Мок для оставшихся экранов

struct MockView: View {
    var body: some View {
        GradientBackground()
    }
}

#Preview {
    TabBarView(appCoordinator: AppCoordinator())
}
