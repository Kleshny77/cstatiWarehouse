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
            waitForAnyRootScreen(app: app, timeout: 20),
            "После запуска должен появиться таббар или экран логина"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }

    @MainActor
    private func waitForAnyRootScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.tabBars.firstMatch.exists {
                return true
            }
            if app.descendants(matching: .any)[UITestAccessibilityIDs.Login.emailField].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
