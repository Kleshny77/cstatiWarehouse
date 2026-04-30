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
    func concurrentEditMerged(serverItem: Item)
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


    func loadCategories() {
        // После миграции 00012 уникальные категории живут только в `OrgCategoriesService`.
        // Старый запрос `warehouseService.fetchCategories` (DISTINCT по items) почти
        // всегда возвращал то же самое и создавал лишний round-trip — убран.
        orgCategoriesService.list(organizationID: organizationID) { [weak self] result in
            guard let self else { return }
            let orgCats: [OrgCategory]
            if case .success(let list) = result {
                orgCats = list
            } else {
                orgCats = []
            }
            self.presenter?.categoriesLoaded(orgCategories: orgCats, extraNames: [])
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


    private func persist(item: Item, isNew: Bool) {
        let completion: (Result<Item, WarehouseError>) -> Void = { [weak self] result in
            switch result {
            case .success(let saved):
                self?.presenter?.saved(saved)
            case .failure(let error):
                if case .concurrentModification(let serverItem) = error {
                    self?.presenter?.concurrentEditMerged(serverItem: serverItem)
                } else {
                    self?.presenter?.failed(error: error.message)
                }
            }
        }

        if isNew {
            warehouseService.createItem(item, organizationID: organizationID, completion: completion)
        } else {
            warehouseService.updateItem(item, completion: completion)
        }
    }
}
