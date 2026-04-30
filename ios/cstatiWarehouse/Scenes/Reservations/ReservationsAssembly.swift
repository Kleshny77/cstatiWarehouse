//
//  ReservationsAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 30.04.2026.
//

import SwiftUI

enum ReservationsAssembly {

    static func assemble(
        item: Item,
        organizationID: UUID,
        currentUserID: UUID,
        isCurrentUserAdmin: Bool
    ) -> some View {
        let presenter = ReservationsPresenter(
            item: item,
            organizationID: organizationID,
            currentUserID: currentUserID,
            isCurrentUserAdmin: isCurrentUserAdmin,
            service: AppServices.reservationsService(),
            organizationsService: AppServices.organizationsService(),
            eventsService: AppServices.eventsService()
        )
        return ReservationsView(presenter: presenter)
    }
}
