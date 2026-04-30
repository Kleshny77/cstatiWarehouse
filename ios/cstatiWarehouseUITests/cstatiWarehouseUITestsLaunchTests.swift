//
//  cstatiWarehouseUITestsLaunchTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import XCTest

/// Один прогон запуска со скриншотом. Без `runsForEachTargetApplicationUIConfiguration`:
/// иначе Xcode гоняет тест по нескольким UI-конфигурациям, на CI часто падает teardown с «Failed to terminate».
final class cstatiWarehouseUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.mainTabsDefaults
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 20),
            "Приложение должно показать UI после запуска"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }
}
