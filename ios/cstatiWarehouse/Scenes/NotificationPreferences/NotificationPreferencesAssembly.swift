//
//  NotificationPreferencesAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

enum NotificationPreferencesAssembly {

    static func makePresenter(
        service: NotificationPreferencesServiceProtocol = AppServices.notificationPreferencesService()
    ) -> NotificationPreferencesPresenter {
        NotificationPreferencesPresenter(service: service)
    }

    static func assemble(
        service: NotificationPreferencesServiceProtocol = AppServices.notificationPreferencesService()
    ) -> some View {
        let presenter = makePresenter(service: service)
        return NotificationPreferencesView(presenter: presenter)
    }
}
