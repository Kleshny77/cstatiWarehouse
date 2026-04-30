//
//  LoginFlowUITests.swift
//  cstatiWarehouseUITests
//
//  Created by Артём on 26.04.2026.
//

import XCTest

final class LoginFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoginScreenShowsEmailAndPasswordGroups() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.loginFlowDefaults
        app.launch()

        let email = app.descendants(matching: .any)[UITestAccessibilityIDs.Login.emailField]
        XCTAssertTrue(email.waitForExistence(timeout: 8))

        let password = app.descendants(matching: .any)[UITestAccessibilityIDs.Login.passwordField]
        XCTAssertTrue(password.waitForExistence(timeout: 2))

        XCTAssertTrue(app.descendants(matching: .any)[UITestAccessibilityIDs.Login.submitButton].exists)
    }

    @MainActor
    func testTapRegisterShowsRegistrationScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = UITestArguments.loginFlowDefaults
        app.launch()

        XCTAssertTrue(app.staticTexts["Добро пожаловать"].waitForExistence(timeout: 8))

        app.descendants(matching: .any)[UITestAccessibilityIDs.Login.registerLink].tap()

        XCTAssertTrue(app.staticTexts["Регистрация"].waitForExistence(timeout: 6))
    }
}
