//
// OrganizationPresenter.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

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
}

@Observable
final class OrganizationPresenter: OrganizationPresenterProtocol {

    // MARK: Properties

    var interactor: OrganizationInteractorInputProtocol?
    var router: OrganizationRouterProtocol?

    var summary: OrganizationSummary?
    var memberRows: [OrganizationMemberRow] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var leaveConfirmation: LeaveConfirmation?
    var deleteConfirmation: DeleteOrgConfirmation?
    var isRenaming: Bool = false

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
            errorMessage = "Владелец не может выйти. Передайте роль другому участнику (появится позже) или удалите организацию."
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
}

// MARK: - OrganizationInteractorOutputProtocol

extension OrganizationPresenter: OrganizationInteractorOutputProtocol {
    func noActiveOrganization() {
        isLoading = false
        summary = nil
        memberRows = []
        lastActiveOrgID = nil
    }

    func summaryLoaded(_ summary: OrganizationSummary, members: [OrganizationMember], currentUserID: UUID?) {
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
        lastActiveOrgID = nil
    }

    func didDelete() {
        summary = nil
        memberRows = []
        lastActiveOrgID = nil
    }

    func didRename(_ summary: OrganizationSummary) {
        self.summary = summary
    }

    func failed(error: String) {
        isLoading = false
        errorMessage = error
    }
}
