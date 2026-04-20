//
//  SettingsInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit

protocol SettingsInteractorInputProtocol: AnyObject {
    func loadUser()
    func updateProfile(name: String?, avatarImage: UIImage?, removeAvatar: Bool)
    func logout()
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func userLoaded(_ user: User?)
    func profileUpdated(_ user: User)
    func profileUpdateFailed(message: String)
    func didLogout()
}

final class SettingsInteractor: SettingsInteractorInputProtocol {

    // MARK: Properties

    weak var presenter: SettingsInteractorOutputProtocol?
    private let sessionStorage: UserSessionStorageProtocol
    private let authService: AuthServiceProtocol
    private let uploadsService: UploadsServiceProtocol
    private let activeOrgStorage: ActiveOrganizationStorageProtocol

    // MARK: Lifecycle

    init(
        sessionStorage: UserSessionStorageProtocol,
        authService: AuthServiceProtocol,
        uploadsService: UploadsServiceProtocol,
        activeOrgStorage: ActiveOrganizationStorageProtocol
    ) {
        self.sessionStorage = sessionStorage
        self.authService = authService
        self.uploadsService = uploadsService
        self.activeOrgStorage = activeOrgStorage
    }

    // MARK: Public Methods

    func loadUser() {
        presenter?.userLoaded(sessionStorage.currentUser)
    }

    func updateProfile(name: String?, avatarImage: UIImage?, removeAvatar: Bool) {
        uploadAvatarIfNeeded(image: avatarImage) { [weak self] avatarURL in
            guard let self else { return }

            let avatarPatch: URL??
            if let avatarURL {
                avatarPatch = .some(avatarURL)
            } else if removeAvatar {
                avatarPatch = .some(nil)
            } else {
                avatarPatch = nil
            }

            let request = UpdateProfileRequest(name: name, avatarURL: avatarPatch)
            self.authService.updateProfile(request: request) { [weak self] result in
                switch result {
                case .success(let dto):
                    let user = User(
                        id: dto.id,
                        email: dto.email,
                        name: dto.name,
                        avatarURL: dto.avatarURL
                    )
                    self?.sessionStorage.updateUser(user)
                    self?.presenter?.profileUpdated(user)
                case .failure(let error):
                    self?.presenter?.profileUpdateFailed(message: error.message)
                }
            }
        }
    }

    func logout() {
        sessionStorage.clear()
        activeOrgStorage.clear()
        presenter?.didLogout()
    }

    // MARK: Private Methods

    private func uploadAvatarIfNeeded(
        image: UIImage?,
        completion: @escaping (URL?) -> Void
    ) {
        guard let image else {
            completion(nil)
            return
        }
        uploadsService.uploadImage(image) { [weak self] result in
            switch result {
            case .success(let url):
                completion(url)
            case .failure(let error):
                self?.presenter?.profileUpdateFailed(message: error.message)
            }
        }
    }
}
