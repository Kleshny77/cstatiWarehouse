//
// TabBarView.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import SwiftUI
import UIKit

struct TabBarView: View {

    let appCoordinator: AppCoordinatorProtocol
    @State private var tabCoordinator: MainTabCoordinator
    @State private var warehousePresenter: MyWarehousePresenter
    @State private var organizationPresenter: OrganizationPresenter
    @State private var overviewPresenter: OverviewPresenter

    init(appCoordinator: AppCoordinatorProtocol) {
        self.appCoordinator = appCoordinator
        let tabs = MainTabCoordinator()
        _tabCoordinator = State(initialValue: tabs)
        _warehousePresenter = State(initialValue: MyWarehouseAssembly.makePresenter(appCoordinator: appCoordinator))
        _organizationPresenter = State(initialValue: OrganizationAssembly.makePresenter(appCoordinator: appCoordinator))
        _overviewPresenter = State(initialValue: OverviewAssembly.makePresenter(tabCoordinator: tabs))
    }

    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            MyWarehouseAssembly.assemble(
                tabCoordinator: tabCoordinator,
                presenter: warehousePresenter
            )
                .tabItem {
                    Label("Мой склад", systemImage: "shippingbox")
                }
                .tag(MainTabCoordinator.Tab.warehouse)

            OrganizationAssembly.assemble(presenter: organizationPresenter)
                .tabItem {
                    Label("Организация", systemImage: "person.2")
                }
                .tag(MainTabCoordinator.Tab.organization)

            OverviewAssembly.assemble(presenter: overviewPresenter)
                .tabItem {
                    Label("Обзор", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(MainTabCoordinator.Tab.overview)
        }
        .tint(Color(hex: "8A80FF"))
        .onAppear {
            TabBarChrome.configureOnceForSmoothSystemTabBar()
        }
        .environment(tabCoordinator)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - UITabBar

private enum TabBarChrome {
    private static var didConfigure = false

    static func configureOnceForSmoothSystemTabBar() {
        guard !didConfigure else { return }
        didConfigure = true

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.42)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.42)]
        itemAppearance.selected.iconColor = UIColor(red: 0.53, green: 0.50, blue: 1.0, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.92)]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }
}

#Preview {
    TabBarView(appCoordinator: AppCoordinator())
}
