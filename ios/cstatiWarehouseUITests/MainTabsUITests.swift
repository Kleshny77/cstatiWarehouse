//
//  MainTabsUITests.swift
//  cstatiWarehouseUITests
//
//  Created by Артём on 26.04.2026.
//

import XCTest

final class MainTabsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabBarSwitchesBetweenWarehouseOrganizationOverview() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.mainTabsDefaults
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 12))

        tabBar.buttons["Обзор"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[UITestAccessibilityIDs.Overview.root].waitForExistence(timeout: 10))

        tabBar.buttons["Организация"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[UITestAccessibilityIDs.Tab.organization].waitForExistence(timeout: 8))

        tabBar.buttons["Мой склад"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[UITestAccessibilityIDs.Tab.warehouse].waitForExistence(timeout: 8))
    }

    @MainActor
    func testOverviewRoutePlanningButtonExists() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.mainTabsDefaults
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 12))
        tabBar.buttons["Обзор"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[UITestAccessibilityIDs.Overview.root].waitForExistence(timeout: 12))

        let routePlanning = app.buttons["Планирование маршрута"]
        XCTAssertTrue(routePlanning.waitForExistence(timeout: 10))
    }

    @MainActor
    func testTabBar_exposesWarehouseOverviewOrganizationTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.mainTabsDefaults
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 12))

        XCTAssertTrue(tabBar.buttons["Обзор"].exists)
        XCTAssertTrue(tabBar.buttons["Мой склад"].exists)
        XCTAssertTrue(tabBar.buttons["Организация"].exists)
    }
}
