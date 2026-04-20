//
//  ItemEditInteractor.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import UIKit

protocol ItemEditInteractorInputProtocol: AnyObject {
    func loadCategories()
    func loadMembers()
    func createOrgCategory(name: String)
    func save(item: Item, image: UIImage?, isNew: Bool)
}

protocol ItemEditInteractorOutputProtocol: AnyObject {
    func categoriesLoaded(orgCategories: [OrgCategory], extraNames: [String])
    func membersLoaded(_ members: [OrganizationMember])
    func orgCategoryCreated(_ category: OrgCategory)
    func saved(_ item: Item)
    func failed(error: String)
}

final class ItemEditInteractor: ItemEditInteractorInputProtocol {
    weak var presenter: ItemEditInteractorOutputProtocol?

    private let warehouseService: WarehouseServiceProtocol
    private let organizationsService: OrganizationsServiceProtocol
    private let orgCategoriesService: OrgCategoriesServiceProtocol
    private let uploadsService: UploadsServiceProtocol
    private let organizationID: UUID

    init(
        warehouseService: WarehouseServiceProtocol,
        organizationsService: OrganizationsServiceProtocol,
        orgCategoriesService: OrgCategoriesServiceProtocol,
        uploadsService: UploadsServiceProtocol,
        organizationID: UUID
    ) {
        self.warehouseService = warehouseService
        self.organizationsService = organizationsService
        self.orgCategoriesService = orgCategoriesService
        self.uploadsService = uploadsService
        self.organizationID = organizationID
    }

    // MARK: Public Methods

    func loadCategories() {
        let group = DispatchGroup()
        var orgCats: [OrgCategory] = []
        var legacyNames: [String] = []

        group.enter()
        orgCategoriesService.list(organizationID: organizationID) { result in
            if case .success(let list) = result {
                orgCats = list
            }
            group.leave()
        }

        group.enter()
        warehouseService.fetchCategories(organizationID: organizationID) { result in
            if case .success(let names) = result {
                legacyNames = names
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let orgNamesLower = Set(orgCats.map { $0.name.lowercased() })
            let extra = legacyNames.filter { name in
                !orgNamesLower.contains(name.lowercased())
            }
            self.presenter?.categoriesLoaded(orgCategories: orgCats, extraNames: extra.sorted { $0.localizedCompare($1) == .orderedAscending })
        }
    }

    func createOrgCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presenter?.failed(error: "Введите название категории")
            return
        }
        orgCategoriesService.create(organizationID: organizationID, name: trimmed) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let category):
                self.presenter?.orgCategoryCreated(category)
                self.loadCategories()
            case .failure(let error):
                self.presenter?.failed(error: error.message)
            }
        }
    }

    func loadMembers() {
        organizationsService.fetchMembers(organizationID: organizationID) { [weak self] result in
            switch result {
            case .success(let members):
                self?.presenter?.membersLoaded(members)
            case .failure:
                self?.presenter?.membersLoaded([])
            }
        }
    }

    func save(item: Item, image: UIImage?, isNew: Bool) {
        guard let image else {
            persist(item: item, isNew: isNew)
            return
        }
        uploadsService.uploadImage(image) { [weak self] result in
            switch result {
            case .success(let url):
                var updated = item
                updated.imageURL = url
                self?.persist(item: updated, isNew: isNew)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }
    }

    // MARK: Private Methods

    private func persist(item: Item, isNew: Bool) {
        let completion: (Result<Item, WarehouseError>) -> Void = { [weak self] result in
            switch result {
            case .success(let saved):
                self?.presenter?.saved(saved)
            case .failure(let error):
                self?.presenter?.failed(error: error.message)
            }
        }

        if isNew {
            warehouseService.createItem(item, organizationID: organizationID, completion: completion)
        } else {
            warehouseService.updateItem(item, completion: completion)
        }
    }
}
