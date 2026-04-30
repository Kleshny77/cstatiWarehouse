//
//  UITestArguments.swift
//  cstatiWarehouseUITests
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum UITestArguments {
    static let skipSplash = "-UITestingSkipSplash"
    static let injectSession = "-UITestingInjectSession"
    static let resetAppState = "-UITestingResetAppState"

    static var loginFlowDefaults: [String] {
        [resetAppState, skipSplash]
    }

    static var mainTabsDefaults: [String] {
        [resetAppState, skipSplash, injectSession]
    }
}
