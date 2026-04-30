//
//  ApiCommentsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

final class ApiCommentsService: CommentsServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List

    func list(
        itemID: UUID,
        completion: @escaping (Result<[ItemComment], CommentsError>) -> Void
    ) {
        apiClient.request(
            path: "/items/\(itemID.uuidString.lowercased())/comments",
            method: .get,
            authenticated: true
        ) { (result: Result<CommentsListDTO, APIError>) in
            switch result {
            case .success(let dto):
                let mapped = dto.items.compactMap { $0.toDomain() }
                completion(.success(mapped))
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Create

    func create(
        itemID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        attachmentURLs: [String],
        parentCommentID: UUID?,
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    ) {
        let body = CreateCommentBody(
            text: text,
            mentionedUserIds: mentionedUserIDs.map { $0.uuidString.lowercased() },
            attachmentUrls: attachmentURLs,
            parentCommentId: parentCommentID?.uuidString.lowercased()
        )
        apiClient.request(
            path: "/items/\(itemID.uuidString.lowercased())/comments",
            method: .post,
            body: body,
            authenticated: true
        ) { (result: Result<ItemCommentDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid comment payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Update

    func update(
        commentID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    ) {
        let body = UpdateCommentBody(
            text: text,
            mentionedUserIds: mentionedUserIDs.map { $0.uuidString.lowercased() }
        )
        apiClient.request(
            path: "/comments/\(commentID.uuidString.lowercased())",
            method: .put,
            body: body,
            authenticated: true
        ) { (result: Result<ItemCommentDTO, APIError>) in
            switch result {
            case .success(let dto):
                if let domain = dto.toDomain() {
                    completion(.success(domain))
                } else {
                    completion(.failure(.unknown("invalid comment payload")))
                }
            case .failure(let err):
                completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Delete

    func delete(
        commentID: UUID,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    ) {
        apiClient.requestVoid(
            path: "/comments/\(commentID.uuidString.lowercased())",
            method: .delete,
            authenticated: true
        ) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let err): completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Reactions

    func addReaction(
        commentID: UUID,
        reaction: CommentReactionType,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    ) {
        let body = ReactionBody(reaction: reaction.rawValue)
        apiClient.requestVoid(
            path: "/comments/\(commentID.uuidString.lowercased())/reactions",
            method: .post,
            body: body,
            authenticated: true
        ) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let err): completion(.failure(Self.mapError(err)))
            }
        }
    }

    func removeReaction(
        commentID: UUID,
        reaction: CommentReactionType,
        completion: @escaping (Result<Void, CommentsError>) -> Void
    ) {
        let query = [URLQueryItem(name: "reaction", value: reaction.rawValue)]
        apiClient.requestVoid(
            path: "/comments/\(commentID.uuidString.lowercased())/reactions",
            method: .delete,
            query: query,
            authenticated: true
        ) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let err): completion(.failure(Self.mapError(err)))
            }
        }
    }

    // MARK: - Helpers

    private static func mapError(_ error: APIError) -> CommentsError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .server(let status, _, let message, _):
            let msg = message ?? "HTTP \(status)"
            switch status {
            case 400, 422: return .validation(msg)
            case 403: return .forbidden
            case 404: return .notFound
            default: return .server(msg)
            }
        case .transport(let underlying):
            return .network(underlying.localizedDescription)
        case .decoding:
            return .unknown("invalid response")
        }
    }
}

// MARK: - DTO

private struct CommentsListDTO: Decodable {
    let items: [ItemCommentDTO]
}

// APIClient.decoder uses .convertFromSnakeCase — explicit snake_case CodingKeys
// would conflict (the strategy converts JSON keys BEFORE CodingKey matching).
// Property names must match the camelCase result of the conversion, and avoid
// consecutive capitals (like "ID", "URL") so .convertToSnakeCase round-trips correctly.
private struct CommentReactionDTO: Decodable {
    let id: String
    let commentId: String
    let userId: String
    let reaction: String
    let createdAt: Date

    func toDomain() -> CommentReaction? {
        guard
            let idValue = UUID(uuidString: id),
            let cid = UUID(uuidString: commentId),
            let uid = UUID(uuidString: userId),
            let type = CommentReactionType(rawValue: reaction)
        else { return nil }
        return CommentReaction(
            id: idValue,
            commentID: cid,
            userID: uid,
            reaction: type,
            createdAt: createdAt
        )
    }
}

private struct ItemCommentDTO: Decodable {
    let id: String
    let itemId: String
    let organizationId: String
    let text: String
    let mentionedUserIds: [String]
    let attachmentUrls: [String]
    let authorUserId: String
    let createdAt: Date
    let updatedAt: Date
    let editedAt: Date?
    let deletedAt: Date?
    let deletedByUserId: String?
    let parentCommentId: String?
    let reactions: [CommentReactionDTO]

    func toDomain() -> ItemComment? {
        guard
            let idValue = UUID(uuidString: id),
            let itemUUID = UUID(uuidString: itemId),
            let orgUUID = UUID(uuidString: organizationId),
            let authorUUID = UUID(uuidString: authorUserId)
        else { return nil }
        let mentions = mentionedUserIds.compactMap { UUID(uuidString: $0) }
        let parent = parentCommentId.flatMap { UUID(uuidString: $0) }
        let deletedBy = deletedByUserId.flatMap { UUID(uuidString: $0) }
        let reacts = reactions.compactMap { $0.toDomain() }
        return ItemComment(
            id: idValue,
            itemID: itemUUID,
            organizationID: orgUUID,
            text: text,
            mentionedUserIDs: mentions,
            attachmentURLs: attachmentUrls,
            authorUserID: authorUUID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            deletedByUserID: deletedBy,
            parentCommentID: parent,
            reactions: reacts
        )
    }
}

// APIClient.encoder uses .convertToSnakeCase — camelCase property names auto-convert.
private struct CreateCommentBody: Encodable {
    let text: String
    let mentionedUserIds: [String]
    let attachmentUrls: [String]
    let parentCommentId: String?
}

private struct UpdateCommentBody: Encodable {
    let text: String
    let mentionedUserIds: [String]
}

private struct ReactionBody: Encodable {
    let reaction: String
}
