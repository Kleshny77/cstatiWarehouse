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
        XCTAssertTrue(app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 8))
    }
}
