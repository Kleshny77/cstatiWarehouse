//
// ActiveOrganizationStorage.swift
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

import Foundation

protocol ActiveOrganizationStorageProtocol: AnyObject {
    var activeOrganizationID: UUID? { get }
    func setActive(_ id: UUID?)
    func clear()
}

final class UserDefaultsActiveOrganizationStorage: ActiveOrganizationStorageProtocol {


    private enum Keys {
        static let activeOrg = "cstatiWarehouse.session.activeOrganizationID"
    }

    private let defaults: UserDefaults


    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }


    var activeOrganizationID: UUID? {
        guard let raw = defaults.string(forKey: Keys.activeOrg) else { return nil }
        return UUID(uuidString: raw)
    }

    func setActive(_ id: UUID?) {
        if let id = id {
            defaults.set(id.uuidString, forKey: Keys.activeOrg)
        } else {
            defaults.removeObject(forKey: Keys.activeOrg)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.activeOrg)
    }
}
