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
        switch mode {
        case .create:
            return "Новая позиция"
        case .createVariant:
            return "Новый вариант"
        case .edit:
            return "Редактирование"
        }
    }

    var currentHolder: OrganizationMember? {
        guard let id = draft.holderID else { return nil }
        return members.first(where: { $0.userID == id })
    }

    /// У карточки-группы количество ведётся по подпозициям — степпер скрываем.
    var hidesQuantityStepper: Bool {
        if case .edit(let item) = mode, item.isProductGroup { return true }
        return false
    }

    var showsMultiPackToggle: Bool {
        if case .create = mode { return true }
        return false
    }

    var showsVariantFields: Bool {
        if case .createVariant = mode { return true }
        return false
    }

    var showsVariantLabelField: Bool {
        if case .createVariant = mode { return true }
        if case .edit(let item) = mode, item.isVariantLine { return true }
        return false
    }

    var quantityLowerBound: Int {
        switch mode {
        case .create:
            return draft.isMultiPackGroup ? 0 : 1
        case .createVariant:
            return 1
        case .edit(let item):
            return item.isProductGroup ? 0 : 0
        }
    }

    var showsMeasureFields: Bool {
        switch mode {
        case .create, .createVariant:
            return true
        case .edit(let item):
            // У группы единица и объём задаются у подпозиций; у корня в API часто `piece`.
            return !item.isProductGroup
        }
    }

    var isNameFieldEditable: Bool {
        if case .createVariant = mode { return false }
        return true
    }

    private let mode: ItemEditMode
    private let currentUserID: UUID?
    private let onFinish: (ItemEditResult) -> Void

    private var isNew: Bool {
        switch mode {
        case .create, .createVariant:
            return true
        case .edit:
            return false
        }
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
        case .createVariant(let parent):
            self.draft = ItemEditDraft.forNewVariant(parent: parent)
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

        switch mode {
        case .create:
            if draft.isMultiPackGroup {
                guard draft.quantity >= 0 else {
                    errorMessage = "Количество не может быть отрицательным"
                    return false
                }
            } else {
                guard draft.quantity >= 1 else {
                    errorMessage = "Количество должно быть не меньше 1"
                    return false
                }
            }
        case .createVariant:
            guard draft.quantity >= 1 else {
                errorMessage = "Количество должно быть не меньше 1"
                return false
            }
            let label = draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                errorMessage = "Укажите подпись (например, 0,7 л), чтобы отличать варианты"
                return false
            }
        case .edit(let original):
            if original.isVariantLine {
                let label = draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else {
                    errorMessage = "Укажите подпись для варианта"
                    return false
                }
            }
            if original.isProductGroup {
                // количество не редактируем
            } else {
                guard draft.quantity >= 0 else {
                    errorMessage = "Количество не может быть отрицательным"
                    return false
                }
            }
        }

        if shouldValidateLiterVolume {
            guard let v = parseVolume(draft.volumePerUnitText), v > 0 else {
                errorMessage = "Укажите объём одной упаковки в литрах (больше 0)"
                return false
            }
        }

        return true
    }

    /// Для карточки-группы поля литров скрыты — валидация по черновику не нужна.
    private var shouldValidateLiterVolume: Bool {
        guard draft.measureUnit == .liter else { return false }
        if case .edit(let original) = mode, original.isProductGroup { return false }
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
            let literVolume = draft.measureUnit == .liter ? parseVolume(draft.volumePerUnitText) : nil
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
                locationAddress: address,
                parentItemID: nil,
                variantLabel: "",
                measureUnit: draft.measureUnit,
                volumePerUnit: literVolume,
                variants: [],
                aggregatedVolumeLiters: nil
            )
        case .createVariant(let parent):
            let label = draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let literVolume = draft.measureUnit == .liter ? parseVolume(draft.volumePerUnitText) : nil
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
                locationAddress: address,
                parentItemID: parent.id,
                variantLabel: label,
                measureUnit: draft.measureUnit,
                volumePerUnit: literVolume,
                variants: [],
                aggregatedVolumeLiters: nil
            )
        case .edit(let original):
            let qty: Int
            if original.isProductGroup {
                qty = original.quantity
            } else {
                qty = draft.quantity
            }
            let measureForSave: ItemMeasureUnit
            let volumeForSave: Double?
            if original.isProductGroup {
                measureForSave = original.measureUnit
                volumeForSave = original.volumePerUnit
            } else {
                measureForSave = draft.measureUnit
                volumeForSave = draft.measureUnit == .liter ? parseVolume(draft.volumePerUnitText) : nil
            }
            return Item(
                id: original.id,
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: qty,
                expirationDate: expiration,
                imageURL: draft.existingImageURL,
                createdAt: original.createdAt,
                status: original.status,
                heldByUserID: draft.holderID ?? original.heldByUserID,
                locationAddress: address,
                parentItemID: original.parentItemID,
                variantLabel: draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                measureUnit: measureForSave,
                volumePerUnit: volumeForSave,
                variants: original.variants,
                aggregatedVolumeLiters: original.aggregatedVolumeLiters
            )
        }
    }

    private func parseVolume(_ raw: String) -> Double? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
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
