//
//  CommentsPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

@Observable
final class CommentsPresenter {

    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Public state (read-only outside presenter)

    private(set) var state: State = .loading
    private(set) var comments: [ItemComment] = []
    private(set) var memberDisplayNames: [UUID: String] = [:]
    private(set) var members: [OrganizationMember] = []

    var editingCommentID: UUID? = nil
    var replyingToCommentID: UUID? = nil

    var inputText: String = ""

    var transientErrorMessage: String?
    private(set) var isSubmitting: Bool = false

    // MARK: - Dependencies

    private let itemID: UUID
    private let organizationID: UUID
    private let currentUserID: UUID
    private let isCurrentUserAdmin: Bool
    private let service: CommentsServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol

    init(
        itemID: UUID,
        organizationID: UUID,
        currentUserID: UUID,
        isCurrentUserAdmin: Bool,
        service: CommentsServiceProtocol,
        organizationsService: OrganizationsServiceProtocol
    ) {
        self.itemID = itemID
        self.organizationID = organizationID
        self.currentUserID = currentUserID
        self.isCurrentUserAdmin = isCurrentUserAdmin
        self.service = service
        self.organizationsService = organizationsService
    }

    // MARK: - Lifecycle

    func onAppear() {
        loadMembers()
        reload()
    }

    func reload() {
        state = .loading
        service.list(itemID: itemID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let items):
                self.comments = items.sorted { $0.createdAt < $1.createdAt }
                self.state = .loaded
            case .failure(let err):
                self.state = .failed(err.message)
            }
        }
    }

    // MARK: - Permissions

    func canEdit(_ comment: ItemComment) -> Bool {
        !comment.isDeleted && comment.authorUserID == currentUserID
    }

    func canDelete(_ comment: ItemComment) -> Bool {
        guard !comment.isDeleted else { return false }
        return comment.authorUserID == currentUserID || isCurrentUserAdmin
    }

    func displayName(for userID: UUID) -> String {
        memberDisplayNames[userID] ?? "Пользователь"
    }

    func isMyReaction(commentID: UUID, type: CommentReactionType) -> Bool {
        guard let comment = comments.first(where: { $0.id == commentID }) else { return false }
        return comment.reactions.contains {
            $0.userID == currentUserID && $0.reaction == type
        }
    }

    // MARK: - Actions

    func startReply(to comment: ItemComment) {
        editingCommentID = nil
        replyingToCommentID = comment.id
    }

    func startEdit(_ comment: ItemComment) {
        replyingToCommentID = nil
        editingCommentID = comment.id
        inputText = comment.text
    }

    func cancelComposing() {
        editingCommentID = nil
        replyingToCommentID = nil
        inputText = ""
    }

    func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }

        let mentions = extractMentions(in: trimmed)

        if let editID = editingCommentID {
            performUpdate(commentID: editID, text: trimmed, mentions: mentions)
        } else {
            performCreate(text: trimmed, mentions: mentions, parent: replyingToCommentID)
        }
    }

    func toggleReaction(comment: ItemComment, type: CommentReactionType) {
        let mine = isMyReaction(commentID: comment.id, type: type)
        applyReactionOptimistically(commentID: comment.id, type: type, add: !mine)

        if mine {
            service.removeReaction(commentID: comment.id, reaction: type) { [weak self] result in
                if case .failure(let err) = result {
                    self?.transientErrorMessage = err.message
                    self?.applyReactionOptimistically(commentID: comment.id, type: type, add: true)
                }
            }
        } else {
            service.addReaction(commentID: comment.id, reaction: type) { [weak self] result in
                if case .failure(let err) = result {
                    self?.transientErrorMessage = err.message
                    self?.applyReactionOptimistically(commentID: comment.id, type: type, add: false)
                }
            }
        }
    }

    func deleteComment(_ comment: ItemComment) {
        guard canDelete(comment) else { return }
        service.delete(commentID: comment.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.reload()
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    // MARK: - Private

    private func performCreate(text: String, mentions: [UUID], parent: UUID?) {
        isSubmitting = true
        service.create(
            itemID: itemID,
            text: text,
            mentionedUserIDs: mentions,
            attachmentURLs: [],
            parentCommentID: parent
        ) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            switch result {
            case .success(let c):
                self.comments.append(c)
                self.comments.sort { $0.createdAt < $1.createdAt }
                self.inputText = ""
                self.replyingToCommentID = nil
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    private func performUpdate(commentID: UUID, text: String, mentions: [UUID]) {
        isSubmitting = true
        service.update(
            commentID: commentID,
            text: text,
            mentionedUserIDs: mentions
        ) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            switch result {
            case .success(let updated):
                if let i = self.comments.firstIndex(where: { $0.id == commentID }) {
                    self.comments[i] = updated
                }
                self.inputText = ""
                self.editingCommentID = nil
            case .failure(let err):
                self.transientErrorMessage = err.message
            }
        }
    }

    private func applyReactionOptimistically(commentID: UUID, type: CommentReactionType, add: Bool) {
        guard let i = comments.firstIndex(where: { $0.id == commentID }) else { return }
        let original = comments[i]
        var newReactions = original.reactions
        if add {
            let r = CommentReaction(
                id: UUID(),
                commentID: commentID,
                userID: currentUserID,
                reaction: type,
                createdAt: Date()
            )
            newReactions.append(r)
        } else {
            newReactions.removeAll {
                $0.userID == currentUserID && $0.reaction == type
            }
        }
        comments[i] = ItemComment(
            id: original.id,
            itemID: original.itemID,
            organizationID: original.organizationID,
            text: original.text,
            mentionedUserIDs: original.mentionedUserIDs,
            attachmentURLs: original.attachmentURLs,
            authorUserID: original.authorUserID,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            editedAt: original.editedAt,
            deletedAt: original.deletedAt,
            deletedByUserID: original.deletedByUserID,
            parentCommentID: original.parentCommentID,
            reactions: newReactions
        )
    }

    private func loadMembers() {
        organizationsService.fetchMembers(organizationID: organizationID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let members):
                self.members = members
                var map: [UUID: String] = [:]
                for m in members {
                    if let n = m.fullName, !n.isEmpty {
                        map[m.userID] = n
                    } else if let e = m.email, !e.isEmpty {
                        map[m.userID] = e
                    } else {
                        map[m.userID] = "Пользователь"
                    }
                }
                self.memberDisplayNames = map
            case .failure:
                break
            }
        }
    }

    private func extractMentions(in text: String) -> [UUID] {
        guard !memberDisplayNames.isEmpty else { return [] }
        let lower = text.lowercased()
        var found: Set<UUID> = []
        for (uid, name) in memberDisplayNames {
            let token = "@" + name.lowercased()
            if lower.contains(token) {
                found.insert(uid)
            }
        }
        return Array(found)
    }
}
