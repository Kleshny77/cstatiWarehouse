//
// OrganizationPresenter.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation
import UIKit

protocol OrganizationPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewDidAppear()
    func refresh()
    func leaveRequested()
    func deleteRequested()
    func confirmLeave()
    func cancelLeave()
    func confirmDelete()
    func cancelDelete()
    func renameRequested()
    func submitRename(_ newName: String)
    func cancelRename()
    func removeMember(_ member: OrganizationMember)
    func promoteToAdmin(_ member: OrganizationMember)
    func demoteToMember(_ member: OrganizationMember)
    func transferOwnership(to member: OrganizationMember)
    func inviteSheetRequested()
    func dismissInviteSheet()
    func createInvite(expiresInDays: Int?, maxUses: Int?)
    func revokeInvite(_ invite: OrganizationInvite)

    // MARK: Events
    func eventsSheetRequested()
    func dismissEventsSheet()
    func createEvent(name: String, description: String, startsAt: Date?)
    func deleteEvent(_ event: OrgEvent)

    // MARK: Categories
    func categoriesSheetRequested()
    func dismissCategoriesSheet()
    func createCategory(name: String)
    func deleteCategory(_ category: OrgCategory)

    // MARK: Activity
    func activitySheetRequested()
    func dismissActivitySheet()
}

@Observable
final class OrganizationPresenter: OrganizationPresenterProtocol {

    // MARK: Properties

    var interactor: OrganizationInteractorInputProtocol?
    var router: OrganizationRouterProtocol?

    var summary: OrganizationSummary?
    var memberRows: [OrganizationMemberRow] = []
    var invites: [OrganizationInvite] = []
    var isLoading: Bool = false
    var errorMessage: String?
    /// Ошибка фоновой загрузки сводки организации — баннер, не модальный алерт.
    var passiveNoticeMessage: String?
    var infoMessage: String?

    var leaveConfirmation: LeaveConfirmation?
    var deleteConfirmation: DeleteOrgConfirmation?
    var isRenaming: Bool = false
    var isInviteSheetPresented: Bool = false
    var isEventsSheetPresented: Bool = false
    var isCategoriesSheetPresented: Bool = false
    var isActivitySheetPresented: Bool = false

    var events: [OrgEvent] = []
    var categories: [OrgCategory] = []
    var activityEntries: [ActivityEntry] = []

    var isLoadingInvites: Bool = false
    var isLoadingEvents: Bool = false
    var isLoadingCategories: Bool = false
    var isLoadingActivity: Bool = false

    private var currentUserID: UUID?
    private var lastActiveOrgID: UUID?

    // MARK: Public Methods

    func viewDidLoad() {
        refresh()
    }

    func viewDidAppear() {
        let active = AppServices.activeOrganizationStorage.activeOrganizationID
        if active != lastActiveOrgID {
            refresh()
        }
    }

    func refresh() {
        passiveNoticeMessage = nil
        isLoading = true
        interactor?.loadSummary()
    }

    func leaveRequested() {
        guard let summary else { return }
        if summary.organization.isPersonal {
            errorMessage = "Нельзя выйти из персональной организации"
            return
        }
        if summary.role == .owner {
            errorMessage = "Владелец не может выйти. Передайте владение другому участнику или удалите организацию."
            return
        }
        leaveConfirmation = LeaveConfirmation(organization: summary.organization)
    }

    func deleteRequested() {
        guard let summary else { return }
        guard summary.role == .owner else {
            errorMessage = "Удалить может только владелец"
            return
        }
        if summary.organization.isPersonal {
            errorMessage = "Персональную организацию удалить нельзя"
            return
        }
        deleteConfirmation = DeleteOrgConfirmation(organization: summary.organization)
    }

    func confirmLeave() {
        guard let target = leaveConfirmation?.organization else { return }
        leaveConfirmation = nil
        interactor?.leave(organizationID: target.id)
    }

    func cancelLeave() {
        leaveConfirmation = nil
    }

    func confirmDelete() {
        guard let target = deleteConfirmation?.organization else { return }
        deleteConfirmation = nil
        interactor?.deleteOrganization(organizationID: target.id)
    }

    func cancelDelete() {
        deleteConfirmation = nil
    }

    func renameRequested() {
        guard let summary, summary.role.canEditOrganization else {
            errorMessage = "Нет прав на изменение"
            return
        }
        if summary.organization.isPersonal {
            errorMessage = "Имя персональной организации изменить нельзя"
            return
        }
        isRenaming = true
    }

    func submitRename(_ newName: String) {
        guard let summary else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Введите название"
            return
        }
        isRenaming = false
        interactor?.rename(organizationID: summary.organization.id, newName: trimmed)
    }

    func cancelRename() {
        isRenaming = false
    }

    func removeMember(_ member: OrganizationMember) {
        guard let summary else { return }
        interactor?.removeMember(organizationID: summary.organization.id, userID: member.userID)
    }

    func promoteToAdmin(_ member: OrganizationMember) {
        guard let summary else { return }
        interactor?.changeRole(organizationID: summary.organization.id, userID: member.userID, role: .admin)
    }

    func demoteToMember(_ member: OrganizationMember) {
        guard let summary else { return }
        interactor?.changeRole(organizationID: summary.organization.id, userID: member.userID, role: .member)
    }

    func transferOwnership(to member: OrganizationMember) {
        guard let summary, summary.role == .owner else { return }
        interactor?.transferOwnership(organizationID: summary.organization.id, newOwnerID: member.userID)
    }

    func inviteSheetRequested() {
        guard let summary, summary.role.canManageMembers else {
            errorMessage = "Нет прав"
            return
        }
        invites = []
        isLoadingInvites = true
        interactor?.loadInvites(organizationID: summary.organization.id)
        isInviteSheetPresented = true
    }

    func dismissInviteSheet() {
        isInviteSheetPresented = false
    }

    func createInvite(expiresInDays: Int?, maxUses: Int?) {
        guard let summary else { return }
        interactor?.createInvite(organizationID: summary.organization.id, expiresInDays: expiresInDays, maxUses: maxUses)
    }

    func revokeInvite(_ invite: OrganizationInvite) {
        guard let summary else { return }
        interactor?.revokeInvite(organizationID: summary.organization.id, inviteID: invite.id)
    }

    func eventsSheetRequested() {
        guard let summary else { return }
        events = []
        isLoadingEvents = true
        interactor?.loadEvents(organizationID: summary.organization.id)
        isEventsSheetPresented = true
    }

    func dismissEventsSheet() {
        isEventsSheetPresented = false
    }

    func createEvent(name: String, description: String, startsAt: Date?) {
        guard let summary else { return }
        guard summary.role.canManageMembers else {
            errorMessage = "Нет прав"
            return
        }
        interactor?.createEvent(
            organizationID: summary.organization.id,
            name: name,
            description: description,
            startsAt: startsAt
        )
    }

    func deleteEvent(_ event: OrgEvent) {
        guard let summary else { return }
        interactor?.deleteEvent(id: event.id, organizationID: summary.organization.id)
    }

    func categoriesSheetRequested() {
        guard let summary else { return }
        categories = []
        isLoadingCategories = true
        interactor?.loadCategories(organizationID: summary.organization.id)
        isCategoriesSheetPresented = true
    }

    func dismissCategoriesSheet() {
        isCategoriesSheetPresented = false
    }

    func createCategory(name: String) {
        guard let summary else { return }
        guard summary.role.canManageMembers else {
            errorMessage = "Нет прав"
            return
        }
        interactor?.createCategory(organizationID: summary.organization.id, name: name)
    }

    func deleteCategory(_ category: OrgCategory) {
        guard let summary else { return }
        interactor?.deleteCategory(id: category.id, organizationID: summary.organization.id)
    }

    func activitySheetRequested() {
        guard let summary else { return }
        activityEntries = []
        isLoadingActivity = true
        interactor?.loadActivity(organizationID: summary.organization.id)
        isActivitySheetPresented = true
    }

    func dismissActivitySheet() {
        isActivitySheetPresented = false
    }
}

// MARK: - OrganizationInteractorOutputProtocol

extension OrganizationPresenter: OrganizationInteractorOutputProtocol {
    func noActiveOrganization() {
        passiveNoticeMessage = nil
        isLoading = false
        summary = nil
        memberRows = []
        invites = []
        lastActiveOrgID = nil
    }

    func loadSummaryFailed(message: String) {
        isLoading = false
        passiveNoticeMessage = message
    }

    func summaryLoaded(_ summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?) {
        passiveNoticeMessage = nil
        self.isLoading = false
        self.summary = summary
        self.currentUserID = currentUserID
        self.lastActiveOrgID = summary.organization.id
        self.memberRows = members.map { member in
            OrganizationMemberRow(
                member: member,
                isCurrentUser: currentUserID.map { $0 == member.userID } ?? false
            )
        }
    }

    func didLeave() {
        summary = nil
        memberRows = []
        invites = []
        lastActiveOrgID = nil
    }

    func didDelete() {
        summary = nil
        memberRows = []
        invites = []
        lastActiveOrgID = nil
    }

    func didRename(_ summary: OrganizationSummary) {
        self.summary = summary
    }

    func invitesLoaded(_ invites: [OrganizationInvite]) {
        self.invites = invites
        self.isLoadingInvites = false
    }

    func inviteCreated(_ invite: OrganizationInvite) {
        UIPasteboard.general.string = invite.code
        AppHaptics.success()
        infoMessage = "Код скопирован в буфер обмена"
        invites.insert(invite, at: 0)
    }

    func memberRemoved(userID: UUID) {
        memberRows.removeAll { $0.member.userID == userID }
    }

    func memberRoleChanged(userID: UUID, role: OrgRole) {
        memberRows = memberRows.map { row in
            guard row.member.userID == userID else { return row }
            var updated = row.member
            updated.role = role
            return OrganizationMemberRow(member: updated, isCurrentUser: row.isCurrentUser)
        }
    }

    func ownershipTransferred() {
        infoMessage = "Владение передано"
    }

    func eventsLoaded(_ events: [OrgEvent]) {
        self.events = events
        self.isLoadingEvents = false
    }

    func categoriesLoaded(_ categories: [OrgCategory]) {
        self.categories = categories
        self.isLoadingCategories = false
    }

    func activityLoaded(_ entries: [ActivityEntry]) {
        self.activityEntries = entries
        self.isLoadingActivity = false
    }

    func failed(error: String) {
        isLoading = false
        isLoadingInvites = false
        isLoadingEvents = false
        isLoadingCategories = false
        isLoadingActivity = false
        errorMessage = error
    }
}
