//
//  CommentsServiceProtocol.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum CommentsError: Error {
    case unauthorized
    case forbidden
    case notFound
    case validation(String)
    case server(String)
    case network(String)
    case unknown(String)

    var message: String {
        switch self {
        case .unauthorized: return "Нужно войти заново"
        case .forbidden: return "Нет доступа к комментарию"
        case .notFound: return "Комментарий не найден"
        case .validation(let m): return m
        case .server(let m): return m
        case .network(let m): return m
        case .unknown(let m): return m
        }
    }
}

protocol CommentsServiceProtocol: AnyObject {
    func list(
        itemID: UUID,
        completion: @escaping (Result<[ItemComment], CommentsError>) -> Void
    )

    func create(
        itemID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        attachmentURLs: [String],
        parentCommentID: UUID?,
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    )

    func update(
        commentID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    )

    func delete(
        commentID: UUID,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    )

    func addReaction(
        commentID: UUID,
        reaction: CommentReactionType,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    )

    func removeReaction(
        commentID: UUID,
        reaction: CommentReactionType,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    )
}
