//
//  CommentsAssembly.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

enum CommentsAssembly {

    static func assemble(
        itemID: UUID,
        organizationID: UUID,
        currentUserID: UUID,
        isCurrentUserAdmin: Bool
    ) -> some View {
        let presenter = CommentsPresenter(
            itemID: itemID,
            organizationID: organizationID,
            currentUserID: currentUserID,
            isCurrentUserAdmin: isCurrentUserAdmin,
            service: AppServices.commentsService(),
            organizationsService: AppServices.organizationsService()
        )
        return CommentsView(presenter: presenter)
    }
}
