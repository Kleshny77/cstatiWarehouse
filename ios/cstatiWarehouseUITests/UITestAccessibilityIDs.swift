//
//  UITestAccessibilityIDs.swift
//  cstatiWarehouseUITests
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum UITestAccessibilityIDs {
    enum Login {
        static let emailField = "login.email"
        static let passwordField = "login.password"
        static let submitButton = "login.submit"
        static let registerLink = "login.register"
    }

    enum Tab {
        static let warehouse = "tab.warehouse"
        static let organization = "tab.organization"
        static let overview = "tab.overview"
    }

    enum Overview {
        static let root = "overview.root"
        static let routePlanningButton = "overview.routePlanning"
    }
}
