//
//  UITestConfiguration.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum UITestingLaunchArgument {
    static let skipSplash = "-UITestingSkipSplash"
    static let injectSession = "-UITestingInjectSession"
    static let resetAppState = "-UITestingResetAppState"
}

enum UITestConfiguration {

    static func prepareIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains(UITestingLaunchArgument.resetAppState) {
            AppServices.sessionStorage.clear()
            AppServices.activeOrganizationStorage.clear()
        }

        guard ProcessInfo.processInfo.arguments.contains(UITestingLaunchArgument.injectSession) else {
            return
        }

        let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let orgID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let user = User(id: userID.uuidString, email: "uitest@local.test", name: "UI", lastName: "Test")
        AppServices.sessionStorage.save(
            user: user,
            accessToken: "uitest.access.token",
            refreshToken: "uitest.refresh.token"
        )
        AppServices.activeOrganizationStorage.setActive(orgID)
    }

    static var shouldSkipSplash: Bool {
        ProcessInfo.processInfo.arguments.contains(UITestingLaunchArgument.skipSplash)
    }
}
