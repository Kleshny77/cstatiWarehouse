//
//  CommentsPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct CommentsPresenterTests {
    @Test
    func canEdit_onlyAuthorWhenNotDeleted() {
        let uid = UUID()
        let sut = makeSUT(currentUserID: uid)
        let open = makeComment(author: uid, deleted: false)
        let deleted = makeComment(author: uid, deleted: true)
        let other = makeComment(author: UUID(), deleted: false)

        #expect(sut.canEdit(open))
        #expect(sut.canEdit(deleted) == false)
        #expect(sut.canEdit(other) == false)
    }

    @Test
    func canDelete_authorOrAdmin() {
        let uid = UUID()
        let sutUser = makeSUT(currentUserID: uid, isAdmin: false)
        let sutAdmin = makeSUT(currentUserID: uid, isAdmin: true)

        let mine = makeComment(author: uid, deleted: false)
        let theirs = makeComment(author: UUID(), deleted: false)

        #expect(sutUser.canDelete(mine))
        #expect(sutUser.canDelete(theirs) == false)
        #expect(sutAdmin.canDelete(theirs))
    }

    @Test
    func cancelComposing_clearsState() {
        let sut = makeSUT()
        sut.inputText = "hello"
        sut.replyingToCommentID = UUID()

        sut.cancelComposing()

        #expect(sut.inputText.isEmpty)
        #expect(sut.replyingToCommentID == nil)
        #expect(sut.editingCommentID == nil)
    }

    @Test
    func submit_emptyInput_doesNothing() {
        let sut = makeSUT()
        sut.inputText = "   "
        sut.submit()
        #expect(sut.isSubmitting == false)
    }

    private func makeSUT(
        currentUserID: UUID = UUID(),
        isAdmin: Bool = false
    ) -> CommentsPresenter {
        CommentsPresenter(
            itemID: UUID(),
            organizationID: UUID(),
            currentUserID: currentUserID,
            isCurrentUserAdmin: isAdmin,
            service: CommentsServiceNoop(),
            organizationsService: OrganizationsMembersNoop()
        )
    }

    private func makeComment(author: UUID, deleted: Bool) -> ItemComment {
        ItemComment(
            id: UUID(),
            itemID: UUID(),
            organizationID: UUID(),
            text: "t",
            mentionedUserIDs: [],
            attachmentURLs: [],
            authorUserID: author,
            createdAt: .now,
            updatedAt: .now,
            editedAt: nil,
            deletedAt: deleted ? .now : nil,
            deletedByUserID: deleted ? author : nil,
            parentCommentID: nil,
            reactions: []
        )
    }
}

private final class CommentsServiceNoop: CommentsServiceProtocol {
    func list(itemID: UUID, completion: @escaping (Result<[ItemComment], CommentsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func create(
        itemID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        attachmentURLs: [String],
        parentCommentID: UUID?,
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.unknown(""))) }
    }

    func update(
        commentID: UUID,
        text: String,
        mentionedUserIDs: [UUID],
        completion: @escaping (Result<ItemComment, CommentsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.unknown(""))) }
    }

    func delete(commentID: UUID, completion: @escaping (Result<Void, CommentsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.unknown(""))) }
    }

    func addReaction(commentID: UUID, reaction: CommentReactionType, completion: @escaping (Result<Void, CommentsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.unknown(""))) }
    }

    func removeReaction(commentID: UUID, reaction: CommentReactionType, completion: @escaping (Result<Void, CommentsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.unknown(""))) }
    }
}

private final class OrganizationsMembersNoop: OrganizationsServiceProtocol {
    func fetchMyOrganizations(completion: @escaping (Result<[OrganizationSummary], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func fetchOrganization(id: UUID, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.notFound)) }
    }

    func createOrganization(name: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func updateOrganization(id: UUID, name: String?, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func deleteOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func fetchMembers(organizationID: UUID, completion: @escaping (Result<[OrganizationMember], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func leaveOrganization(id: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func removeMember(organizationID: UUID, userID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func changeMemberRole(
        organizationID: UUID,
        userID: UUID,
        role: OrgRole,
        completion: @escaping (Result<Void, OrganizationsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func listInvites(organizationID: UUID, completion: @escaping (Result<[OrganizationInvite], OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.success([])) }
    }

    func createInvite(
        organizationID: UUID,
        expiresInDays: Int?,
        maxUses: Int?,
        completion: @escaping (Result<OrganizationInvite, OrganizationsError>) -> Void
    ) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func revokeInvite(organizationID: UUID, inviteID: UUID, completion: @escaping (Result<Void, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }

    func joinByCode(_ code: String, completion: @escaping (Result<OrganizationSummary, OrganizationsError>) -> Void) {
        DispatchQueue.main.async { completion(.failure(.serverError(""))) }
    }
}
