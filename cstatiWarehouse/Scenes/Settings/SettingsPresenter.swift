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

        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = trimmed != (user?.name ?? "") && !trimmed.isEmpty
        let avatarChanged = pickedAvatar != nil || removeAvatarRequested

        guard nameChanged || avatarChanged else { return }

        if trimmed.isEmpty && nameChanged {
            errorMessage = "Имя не может быть пустым"
            return
        }

        isSaving = true
        interactor?.updateProfile(
            name: nameChanged ? trimmed : nil,
            avatarImage: pickedAvatar,
            removeAvatar: removeAvatarRequested && pickedAvatar == nil
        )
    }

    func logoutButtonTapped() {
        interactor?.logout()
    }

    var hasPendingChanges: Bool {
        guard let user else { return false }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = !trimmed.isEmpty && trimmed != user.name
        let avatarChanged = pickedAvatar != nil || removeAvatarRequested
        return nameChanged || avatarChanged
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func userLoaded(_ user: User?) {
        self.user = user
        self.draftName = user?.name ?? ""
        self.pickedAvatar = nil
        self.removeAvatarRequested = false
    }

    func profileUpdated(_ user: User) {
        self.user = user
        self.draftName = user.name
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
