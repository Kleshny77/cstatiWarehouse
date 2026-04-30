//
//  ItemComment.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum CommentReactionType: String, CaseIterable, Hashable, Codable {
    case thumbsUp = "thumbs_up"
    case thumbsDown = "thumbs_down"
    case heart
    case laugh
    case party
    case eyes

    var emoji: String {
        switch self {
        case .thumbsUp: return "👍"
        case .thumbsDown: return "👎"
        case .heart: return "❤️"
        case .laugh: return "😂"
        case .party: return "🎉"
        case .eyes: return "👀"
        }
    }
}

struct CommentReaction: Identifiable, Hashable {
    let id: UUID
    let commentID: UUID
    let userID: UUID
    let reaction: CommentReactionType
    let createdAt: Date
}

struct ItemComment: Identifiable, Hashable {
    let id: UUID
    let itemID: UUID
    let organizationID: UUID

    let text: String
    let mentionedUserIDs: [UUID]
    let attachmentURLs: [String]

    let authorUserID: UUID

    let createdAt: Date
    let updatedAt: Date
    let editedAt: Date?

    let deletedAt: Date?
    let deletedByUserID: UUID?

    let parentCommentID: UUID?

    let reactions: [CommentReaction]

    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { editedAt != nil }

    var reactionCounts: [(type: CommentReactionType, count: Int, mine: Bool)] {
        Dictionary(grouping: reactions, by: { $0.reaction })
            .map { (type: $0.key, count: $0.value.count, mine: false) }
            .sorted { $0.count > $1.count }
    }
}
