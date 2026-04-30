//
//  cstatiWarehouseUITests.swift
//  cstatiWarehouseUITests
//
//  Created by Artem Samsonov on 16.01.2026.
//

import XCTest

final class cstatiWarehouseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.loginFlowDefaults
        app.launch()
        let email = app.descendants(matching: .any)[UITestAccessibilityIDs.Login.emailField]
        XCTAssertTrue(email.waitForExistence(timeout: 12))
    }
}
