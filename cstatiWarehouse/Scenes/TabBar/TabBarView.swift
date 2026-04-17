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
            MyWarehouseAssembly.assemble(appCoordinator: appCoordinator)
                .tabItem {
                    Image(systemName: "shippingbox")
                    Text("Мой склад")
                }
            MockView()
                .tabItem {
                    Image(systemName: "cancel")
                    Text("Организация")
                }
            MockView()
                .tabItem {
                    Image(systemName: "pencil")
                    Text("Настройки")
                }
        }
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
