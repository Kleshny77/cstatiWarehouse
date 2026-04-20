//
//  ItemEditPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import SwiftUI

protocol ItemEditPresenterProtocol: AnyObject {
    func viewDidLoad()
    func selectCategory(name: String)
    func selectHolder(_ member: OrganizationMember)
    func createNewCategory(name: String)
    func saveButtonTapped()
    func cancelButtonTapped()
}

@Observable
final class ItemEditPresenter: ItemEditPresenterProtocol {
    // MARK: Properties

    var interactor: ItemEditInteractorInputProtocol?
    var router: ItemEditRouterProtocol?

    var draft: ItemEditDraft
    /// Категории из справочника организации.
    var orgCategories: [OrgCategory] = []
    /// Названия категорий только из старых позиций (ещё не в справочнике).
    var extraCategoryNames: [String] = []
    var members: [OrganizationMember] = []
    var errorMessage: String?
    var isSaving: Bool = false
    var isHolderPickerPresented: Bool = false
    var isNewCategorySheetPresented: Bool = false

    var screenTitle: String {
        isNew ? "Новая позиция" : "Редактирование"
    }

    var currentHolder: OrganizationMember? {
        guard let id = draft.holderID else { return nil }
        return members.first(where: { $0.userID == id })
    }

    private let mode: ItemEditMode
    private let currentUserID: UUID?
    private let onFinish: (ItemEditResult) -> Void

    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }

    // MARK: Lifecycle

    init(mode: ItemEditMode, currentUserID: UUID?, onFinish: @escaping (ItemEditResult) -> Void) {
        self.mode = mode
        self.currentUserID = currentUserID
        self.onFinish = onFinish
        switch mode {
        case .create(let suggestedCategory):
            var draft = ItemEditDraft.empty(suggestedCategory: suggestedCategory)
            draft.holderID = currentUserID
            self.draft = draft
        case .edit(let item):
            self.draft = .from(item: item)
        }
    }

    // MARK: Public Methods

    func viewDidLoad() {
        interactor?.loadCategories()
        interactor?.loadMembers()
    }

    func selectHolder(_ member: OrganizationMember) {
        draft.holderID = member.userID
        isHolderPickerPresented = false
    }

    func selectCategory(name: String) {
        draft.categoryName = name
    }

    func createNewCategory(name: String) {
        interactor?.createOrgCategory(name: name)
    }

    func saveButtonTapped() {
        guard validate() else { return }

        let item = buildItem()
        isSaving = true
        interactor?.save(item: item, image: draft.pickedImage, isNew: isNew)
    }

    func cancelButtonTapped() {
        onFinish(.cancelled)
    }

    // MARK: Private Methods

    private func validate() -> Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            errorMessage = "Введите название"
            return false
        }
        guard !category.isEmpty else {
            errorMessage = "Выберите или создайте категорию"
            return false
        }
        guard draft.quantity >= 1 else {
            errorMessage = "Количество должно быть не меньше 1"
            return false
        }
        return true
    }

    private func buildItem() -> Item {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedDescription.isEmpty ? nil : trimmedDescription
        let expiration = draft.hasShelfLife ? draft.expirationDate : nil
        let trimmedAddress = draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = trimmedAddress.isEmpty ? nil : trimmedAddress

        switch mode {
        case .create:
            return Item(
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: draft.quantity,
                expirationDate: expiration,
                imageURL: draft.existingImageURL,
                createdAt: .now,
                status: .inStock,
                heldByUserID: draft.holderID ?? currentUserID,
                locationAddress: address
            )
        case .edit(let original):
            return Item(
                id: original.id,
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: draft.quantity,
                expirationDate: expiration,
                imageURL: draft.existingImageURL,
                createdAt: original.createdAt,
                status: original.status,
                heldByUserID: draft.holderID ?? original.heldByUserID,
                locationAddress: address
            )
        }
    }
}

// MARK: - ItemEditInteractorOutputProtocol

extension ItemEditPresenter: ItemEditInteractorOutputProtocol {
    func categoriesLoaded(orgCategories: [OrgCategory], extraNames: [String]) {
        self.orgCategories = orgCategories
        self.extraCategoryNames = extraNames
    }

    func orgCategoryCreated(_ category: OrgCategory) {
        draft.categoryName = category.name
        isNewCategorySheetPresented = false
    }

    func membersLoaded(_ members: [OrganizationMember]) {
        self.members = members
        if draft.holderID == nil, let currentUserID, members.contains(where: { $0.userID == currentUserID }) {
            draft.holderID = currentUserID
        }
    }

    func saved(_ item: Item) {
        isSaving = false
        onFinish(.saved(item))
    }

    func failed(error: String) {
        isSaving = false
        errorMessage = error
    }
}
