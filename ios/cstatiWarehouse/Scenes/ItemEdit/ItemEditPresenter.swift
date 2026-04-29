//
//  ItemEditPresenter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import CoreLocation
import Foundation
import SwiftUI

protocol ItemEditPresenterProtocol: AnyObject {
    func viewDidLoad()
    func locationAddressChanged()
    func selectCategory(name: String)
    func selectHolder(_ member: OrganizationMember)
    func createNewCategory(name: String)
    func saveButtonTapped()
    func cancelButtonTapped()
}

@Observable
final class ItemEditPresenter: ItemEditPresenterProtocol {

    var interactor: ItemEditInteractorInputProtocol?
    var router: ItemEditRouterProtocol?

    var draft: ItemEditDraft
    var orgCategories: [OrgCategory] = []
    var extraCategoryNames: [String] = []
    var members: [OrganizationMember] = []
    var errorMessage: String?
    var isSaving: Bool = false
    var isHolderPickerPresented: Bool = false
    var isNewCategorySheetPresented: Bool = false

    /// Автоматическая проверка адреса (геокодинг + миникарта под полем).
    private(set) var addressGeocodePreviewStatus: AddressGeocodeInlineStatus = .hidden

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

    var hidesQuantityStepper: Bool {
        if let o = resolvedEditOriginal(), o.isProductGroup { return true }
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
        if let o = resolvedEditOriginal(), o.isVariantLine { return true }
        return false
    }

    var quantityLowerBound: Int {
        switch mode {
        case .create:
            return draft.isMultiPackGroup ? 0 : 1
        case .createVariant:
            return 1
        case .edit:
            return 0
        }
    }

    var showsMeasureFields: Bool {
        switch mode {
        case .create, .createVariant:
            return true
        case .edit:
            guard let o = resolvedEditOriginal() else { return true }
            return !o.isProductGroup
        }
    }

    /// Заголовок поля размера упаковки (зависит от меры).
    var amountPerPackageFieldTitle: String {
        switch draft.measureUnit {
        case .liter:
            return "Литров в одной упаковке"
        case .milliliter:
            return "Миллилитров в одной упаковке"
        case .kilogram:
            return "Килограммов в одной упаковке"
        case .gram:
            return "Граммов в одной упаковке"
        case .piece:
            return "Штук в одной упаковке"
        }
    }

    var amountPerPackagePlaceholder: String {
        switch draft.measureUnit {
        case .liter:
            return "например, 1 или 0,7"
        case .milliliter:
            return "например, 500"
        case .kilogram:
            return "например, 25"
        case .gram:
            return "например, 400"
        case .piece:
            return "например, 500"
        }
    }

    private var validatesAmountPerPackageField: Bool {
        switch mode {
        case .create, .createVariant:
            return true
        case .edit:
            guard let o = resolvedEditOriginal() else { return true }
            return !o.isProductGroup
        }
    }

    var isNameFieldEditable: Bool {
        if case .createVariant = mode { return false }
        return true
    }

    private let mode: ItemEditMode
    private let currentUserID: UUID?
    private let onFinish: (ItemEditResult) -> Void

    private let geocoder: AddressGeocoderProtocol
    private let addressGeocodeDebounce: TimeInterval
    private var geocodeWorkItem: DispatchWorkItem?
    private var lastSuccessfulAddressFingerprint: String?
    private var didRunInitialViewLoad: Bool = false

    /// Базовая позиция для режима редактирования (обновляется при конфликте версий с сервером).
    private var editBaselineItem: Item?

    private var isNew: Bool {
        switch mode {
        case .create, .createVariant:
            return true
        case .edit:
            return false
        }
    }


    init(
        mode: ItemEditMode,
        currentUserID: UUID?,
        geocoder: AddressGeocoderProtocol = AddressGeocoder(),
        addressGeocodeDebounce: TimeInterval = 0.45,
        onFinish: @escaping (ItemEditResult) -> Void
    ) {
        self.mode = mode
        self.currentUserID = currentUserID
        self.geocoder = geocoder
        self.addressGeocodeDebounce = addressGeocodeDebounce
        self.onFinish = onFinish
        switch mode {
        case .create(let suggestedCategory):
            var draft = ItemEditDraft.empty(suggestedCategory: suggestedCategory)
            draft.holderID = currentUserID
            self.draft = draft
        case .createVariant(let parent):
            self.draft = ItemEditDraft.forNewVariant(parent: parent)
        case .edit(let item):
            self.editBaselineItem = item
            self.draft = .from(item: item)
        }

        updateAddressPreviewVisibilityForCurrentDraft()
    }

    private func resolvedEditOriginal() -> Item? {
        guard case .edit(let fallback) = mode else { return nil }
        return editBaselineItem ?? fallback
    }

    func locationAddressChanged() {
        geocodeWorkItem?.cancel()
        let trimmed = draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if addressGeocodePreviewStatus != .hidden {
                addressGeocodePreviewStatus = .hidden
            }
            lastSuccessfulAddressFingerprint = nil
            return
        }

        if case .ok = addressGeocodePreviewStatus,
           lastSuccessfulAddressFingerprint == trimmed {
            return
        }

        if let fp = lastSuccessfulAddressFingerprint, fp != trimmed {
            lastSuccessfulAddressFingerprint = nil
        }

        switch addressGeocodePreviewStatus {
        case .idleTyping:
            break
        default:
            addressGeocodePreviewStatus = .idleTyping
        }

        let work = DispatchWorkItem { [weak self] in
            self?.runGeocode(forTrimmedAddress: trimmed)
        }
        geocodeWorkItem = work
        if addressGeocodeDebounce <= 0 {
            DispatchQueue.main.async(execute: work)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + addressGeocodeDebounce, execute: work)
        }
    }

    private func runGeocode(forTrimmedAddress trimmed: String) {
        addressGeocodePreviewStatus = .checking
        geocoder.geocodeAddress(trimmed) { [weak self] result in
            guard let self else { return }
            let current = self.draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard current == trimmed else { return }
            switch result {
            case .success(let coord):
                self.lastSuccessfulAddressFingerprint = trimmed
                self.addressGeocodePreviewStatus = .ok(latitude: coord.latitude, longitude: coord.longitude)
            case .failure(let error):
                self.lastSuccessfulAddressFingerprint = nil
                self.addressGeocodePreviewStatus = .failed(GeocodingUserMessage.message(for: error))
            }
        }
    }

    private func updateAddressPreviewVisibilityForCurrentDraft() {
        let trimmed = draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            addressGeocodePreviewStatus = .hidden
        } else if addressGeocodePreviewStatus == .hidden {
            addressGeocodePreviewStatus = .idleTyping
        }
    }


    func viewDidLoad() {
        if !didRunInitialViewLoad {
            didRunInitialViewLoad = true
            interactor?.loadCategories()
            interactor?.loadMembers()
        }
        locationAddressChanged()
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

        let trimmedAddress = draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            errorMessage = "Укажите адрес хранения"
            return false
        }

        guard lastSuccessfulAddressFingerprint == trimmedAddress,
              case .ok = addressGeocodePreviewStatus else {
            switch addressGeocodePreviewStatus {
            case .checking:
                errorMessage = "Подождите: адрес проверяется на карте."
            case .failed:
                errorMessage = "Исправьте адрес по подсказке под полем — он не найден на карте."
            case .idleTyping:
                errorMessage = "Проверка адреса ещё не завершена. Подождите или допишите адрес до конца."
            default:
                errorMessage = "Дождитесь, пока адрес появится на карте ниже, или уточните формулировку."
            }
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
        case .edit:
            guard let original = resolvedEditOriginal() else { return false }
            if original.isVariantLine {
                let label = draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else {
                    errorMessage = "Укажите подпись для варианта"
                    return false
                }
            }
            if original.isProductGroup {
            } else {
                guard draft.quantity >= 0 else {
                    errorMessage = "Количество не может быть отрицательным"
                    return false
                }
            }
        }

        if validatesAmountPerPackageField {
            let raw = draft.volumePerUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                guard let v = parseVolume(raw), v > 0 else {
                    errorMessage = "Размер упаковки должен быть больше 0 или оставьте поле пустым (= 1)"
                    return false
                }
            }
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
                locationAddress: trimmedAddress,
                parentItemID: nil,
                variantLabel: "",
                measureUnit: draft.measureUnit,
                volumePerUnit: volumePointerFromDraft(),
                variants: [],
                aggregatedVolumeLiters: nil
            )
        case .createVariant(let parent):
            let label = draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines)
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
                locationAddress: trimmedAddress,
                parentItemID: parent.id,
                variantLabel: label,
                measureUnit: draft.measureUnit,
                volumePerUnit: volumePointerFromDraft(),
                variants: [],
                aggregatedVolumeLiters: nil
            )
        case .edit:
            guard let original = resolvedEditOriginal() else {
                fatalError("ItemEditPresenter: edit mode without baseline item")
            }
            let qty: Int
            if original.isProductGroup {
                qty = original.quantity
            } else {
                qty = draft.quantity
            }
            let measureForSave: ItemMeasureUnit = original.isProductGroup ? original.measureUnit : draft.measureUnit
            let volumeForSave: Double? = original.isProductGroup ? original.volumePerUnit : volumePointerFromDraft()
            return Item(
                id: original.id,
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: qty,
                expirationDate: expiration,
                imageURL: draft.existingImageURL,
                createdAt: original.createdAt,
                updatedAt: original.updatedAt,
                status: original.status,
                heldByUserID: draft.holderID ?? original.heldByUserID,
                locationAddress: trimmedAddress,
                parentItemID: original.parentItemID,
                variantLabel: draft.variantLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                measureUnit: measureForSave,
                volumePerUnit: volumeForSave,
                variants: original.variants,
                aggregatedVolumeLiters: original.aggregatedVolumeLiters
            )
        }
    }

    private func volumePointerFromDraft() -> Double? {
        let raw = draft.volumePerUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        return parseVolume(raw)
    }

    private func parseVolume(_ raw: String) -> Double? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}


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

    func concurrentEditMerged(serverItem: Item) {
        isSaving = false
        editBaselineItem = serverItem
        draft = ItemEditDraft.from(item: serverItem)
        errorMessage = WarehouseError.concurrentModification(serverItem).message
    }

    func failed(error: String) {
        isSaving = false
        errorMessage = error
    }
}
