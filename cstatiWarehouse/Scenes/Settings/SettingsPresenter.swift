//
//  SettingsPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit

protocol SettingsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func saveButtonTapped()
    func logoutButtonTapped()
}

@Observable
final class SettingsPresenter: SettingsPresenterProtocol {

    // MARK: Properties

    var interactor: SettingsInteractorInputProtocol?
    var router: SettingsRouterProtocol?

    var user: User?
    var draftName: String = ""
    var draftLastName: String = ""
    var pickedAvatar: UIImage?
    var removeAvatarRequested: Bool = false

    var isSaving: Bool = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: Public Methods

    func viewDidLoad() {
        interactor?.loadUser()
    }

    func saveButtonTapped() {
        guard !isSaving else { return }

        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = draftLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !trimmedName.isEmpty && trimmedName != (user?.name ?? "")
        let lastNameChanged = trimmedLastName != (user?.lastName ?? "")
        let avatarChanged = pickedAvatar != nil || removeAvatarRequested

        guard nameChanged || lastNameChanged || avatarChanged else { return }

        if trimmedName.isEmpty {
            errorMessage = "Имя не может быть пустым"
            return
        }

        isSaving = true
        interactor?.updateProfile(
            name: nameChanged ? trimmedName : nil,
            lastName: lastNameChanged ? trimmedLastName : nil,
            avatarImage: pickedAvatar,
            removeAvatar: removeAvatarRequested && pickedAvatar == nil
        )
    }

    func logoutButtonTapped() {
        interactor?.logout()
    }

    var hasPendingChanges: Bool {
        guard let user else { return false }
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = draftLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !trimmedName.isEmpty && trimmedName != user.name
        let lastNameChanged = trimmedLastName != user.lastName
        let avatarChanged = pickedAvatar != nil || removeAvatarRequested
        return nameChanged || lastNameChanged || avatarChanged
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func userLoaded(_ user: User?) {
        self.user = user
        self.draftName = user?.name ?? ""
        self.draftLastName = user?.lastName ?? ""
        self.pickedAvatar = nil
        self.removeAvatarRequested = false
    }

    func profileUpdated(_ user: User) {
        self.user = user
        self.draftName = user.name
        self.draftLastName = user.lastName
        self.pickedAvatar = nil
        self.removeAvatarRequested = false
        self.isSaving = false
        self.successMessage = "Профиль обновлён"
    }

    func profileUpdateFailed(message: String) {
        self.isSaving = false
        self.errorMessage = message
    }

    func didLogout() {
        router?.navigateToLogin()
    }
}
