//
//  TabBarView.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 01.02.2026.
//

import SwiftUI

struct TabBar: View {
    var body: some View {
        TabView {
          MockView()
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
        .background(.gray)
    }
}

// MARK: - Мок для оставшихся экранов
struct MockView: View {
    var body: some View {
        Text("Some view")
    }
}

#Preview() {
  TabBar()
}
