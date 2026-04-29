//
//  ItemEditPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import CoreLocation
import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct ItemEditPresenterTests {
    @Test
    func create_withSuggestedCategory_fillsDraftCategory() {
        let (sut, _, _) = makeSUT(mode: .create(suggestedCategory: "напитки"))
        
        #expect(sut.draft.name == "")
        #expect(sut.draft.description == "")
        #expect(sut.draft.categoryName == "напитки")
        #expect(sut.draft.quantity == 1)
        #expect(sut.draft.hasShelfLife == false)
        #expect(sut.screenTitle == "Новая позиция")
    }
    
    @Test
    func edit_withExistingItem_populatesDraft() {
        let date = Date.now
        let item = Item(
            name: "пиво",
            description: "светлое",
            categoryName: "напитки",
            quantity: 4,
            expirationDate: date,
            status: .inStock
        )
        let (sut, _, _) = makeSUT(mode: .edit(item))
        
        #expect(sut.draft.name == "пиво")
        #expect(sut.draft.description == "светлое")
        #expect(sut.draft.categoryName == "напитки")
        #expect(sut.draft.quantity == 4)
        #expect(sut.draft.hasShelfLife == true)
        #expect(sut.draft.expirationDate == date)
        #expect(sut.screenTitle == "Редактирование")
    }
    
    @Test
    func saveButtonTapped_withoutName_setsError_andDoesNotCallInteractor() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "напитки"))
        sut.draft.name = "   "
        
        sut.saveButtonTapped()
        
        #expect(sut.errorMessage == "Введите название")
        #expect(fake.saveCalls.isEmpty)
    }
    
    @Test
    func saveButtonTapped_withoutCategory_setsError() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: nil))
        sut.draft.name = "x"
        sut.draft.categoryName = ""
        
        sut.saveButtonTapped()
        
        #expect(sut.errorMessage == "Выберите или создайте категорию")
        #expect(fake.saveCalls.isEmpty)
    }
    
    @Test
    func saveButtonTapped_withInvalidQuantity_setsError() async {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "x"
        sut.draft.quantity = 0
        await primeValidatedAddress(sut)

        sut.saveButtonTapped()

        #expect(sut.errorMessage == "Количество должно быть не меньше 1")
        #expect(fake.saveCalls.isEmpty)
    }

    @Test
    func saveButtonTapped_create_buildsItemAndCallsInteractorAsNew() async {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "  пиво  "
        sut.draft.description = "  светлое  "
        sut.draft.quantity = 3
        sut.draft.hasShelfLife = false
        await primeValidatedAddress(sut)

        sut.saveButtonTapped()

        #expect(sut.isSaving == true)
        #expect(fake.saveCalls.count == 1)
        let (item, _, isNew) = fake.saveCalls[0]
        #expect(isNew == true)
        #expect(item.name == "пиво")
        #expect(item.description == "светлое")
        #expect(item.categoryName == "cat")
        #expect(item.quantity == 3)
        #expect(item.expirationDate == nil)
        #expect(item.status == .inStock)
    }

    @Test
    func saveButtonTapped_emptyDescription_producesNilDescription() async {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "x"
        sut.draft.description = "   "
        await primeValidatedAddress(sut)

        sut.saveButtonTapped()

        #expect(fake.saveCalls.first?.0.description == nil)
        #expect(fake.saveCalls.first?.1 == nil)
    }

    @Test
    func saveButtonTapped_edit_preservesIdAndCreatedAtAndStatus() async {
        let original = Item(
            id: UUID(),
            name: "orig",
            categoryName: "c",
            quantity: 1,
            createdAt: Date(timeIntervalSince1970: 1000),
            status: .inStock
        )
        let (sut, fake, _) = makeSUT(mode: .edit(original))
        sut.draft.name = "edited"
        await primeValidatedAddress(sut)

        sut.saveButtonTapped()

        let (item, _, isNew) = fake.saveCalls[0]
        #expect(isNew == false)
        #expect(item.id == original.id)
        #expect(item.createdAt == original.createdAt)
        #expect(item.status == original.status)
        #expect(item.name == "edited")
    }

    @Test
    func saved_callsOnFinishWithSavedItem_andClearsSaving() async {
        let (sut, _, spy) = makeSUT(mode: .create(suggestedCategory: "c"))
        sut.draft.name = "x"
        await primeValidatedAddress(sut)
        sut.saveButtonTapped()

        let savedItem = Item(name: "x", categoryName: "c")
        sut.saved(savedItem)

        #expect(sut.isSaving == false)
        guard case .saved(let returned) = spy.lastResult else {
            Issue.record("Expected .saved, got \(String(describing: spy.lastResult))")
            return
        }
        #expect(returned.id == savedItem.id)
    }

    @Test
    func failed_setsErrorMessage_andDoesNotFinish() async {
        let (sut, _, spy) = makeSUT(mode: .create(suggestedCategory: "c"))
        sut.draft.name = "x"
        await primeValidatedAddress(sut)
        sut.saveButtonTapped()

        sut.failed(error: "Ошибка сервера")

        #expect(sut.isSaving == false)
        #expect(sut.errorMessage == "Ошибка сервера")
        #expect(spy.lastResult == nil)
    }
    
    @Test
    func cancelButtonTapped_callsOnFinishCancelled() {
        let (sut, _, spy) = makeSUT(mode: .create(suggestedCategory: "c"))
        
        sut.cancelButtonTapped()
        
        guard case .cancelled = spy.lastResult else {
            Issue.record("Expected .cancelled, got \(String(describing: spy.lastResult))")
            return
        }
    }
    
    @Test
    func viewDidLoad_requestsCategoriesAndMembersFromInteractor() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: nil))
        
        sut.viewDidLoad()
        
        #expect(fake.loadCategoriesCallCount == 1)
        #expect(fake.loadMembersCallCount == 1)
    }
    
    @Test
    func categoriesLoaded_populatesOrgCategoriesAndExtraNames() {
        let (sut, _, _) = makeSUT(mode: .create(suggestedCategory: nil))
        let orgID = UUID()
        let eda = OrgCategory(
            id: UUID(),
            organizationID: orgID,
            name: "еда",
            createdByID: UUID(),
            createdAt: .now
        )
        let drinks = OrgCategory(
            id: UUID(),
            organizationID: orgID,
            name: "напитки",
            createdByID: UUID(),
            createdAt: .now
        )
        
        sut.categoriesLoaded(orgCategories: [eda, drinks], extraNames: ["старая"])
        
        #expect(sut.orgCategories.map(\.name).sorted() == ["еда", "напитки"])
        #expect(sut.extraCategoryNames == ["старая"])
    }
    
    @Test
    func selectCategory_writesIntoDraft() {
        let (sut, _, _) = makeSUT(mode: .create(suggestedCategory: nil))
        
        sut.selectCategory(name: "напитки")
        
        #expect(sut.draft.categoryName == "напитки")
    }
    
    @Test
    func edit_productGroup_hidesMeasureFields() {
        let parentID = UUID()
        let variant = Item(
            name: "Сок",
            categoryName: "напитки",
            quantity: 2,
            parentItemID: parentID,
            variantLabel: "1 л",
            measureUnit: .liter
        )
        let parent = Item(
            id: parentID,
            name: "Сок",
            categoryName: "напитки",
            quantity: 0,
            measureUnit: .piece,
            variants: [variant]
        )
        let (sut, _, _) = makeSUT(mode: .edit(parent))

        #expect(sut.showsMeasureFields == false)
    }

    @Test
    func saveButtonTapped_edit_productGroup_preservesRootMeasureUnitFromOriginal() async {
        let parentID = UUID()
        let variant = Item(
            name: "Сок",
            categoryName: "напитки",
            quantity: 2,
            parentItemID: parentID,
            variantLabel: "1 л",
            measureUnit: .liter
        )
        let parent = Item(
            id: parentID,
            name: "Сок",
            categoryName: "напитки",
            quantity: 0,
            measureUnit: .piece,
            variants: [variant]
        )
        let (sut, fake, _) = makeSUT(mode: .edit(parent))
        sut.draft.name = "Сок яблочный"
        await primeValidatedAddress(sut)

        sut.saveButtonTapped()

        #expect(fake.saveCalls.count == 1)
        let (item, _, isNew) = fake.saveCalls[0]
        #expect(isNew == false)
        #expect(item.measureUnit == .piece)
        #expect(item.name == "Сок яблочный")
    }

    private final class OnFinishSpy: @unchecked Sendable {
        var lastResult: ItemEditResult?
    }
    
    private func primeValidatedAddress(_ sut: ItemEditPresenter) async {
        sut.draft.locationAddress = "Москва, ул. Тестовая, 1"
        sut.locationAddressChanged()
        await Task.yield()
    }

    private func makeSUT(
        mode: ItemEditMode,
        geocoder: AddressGeocoderProtocol = ImmediateSuccessGeocoder()
    ) -> (ItemEditPresenter, FakeItemEditInteractor, OnFinishSpy) {
        let spy = OnFinishSpy()
        let fake = FakeItemEditInteractor()
        let presenter = ItemEditPresenter(
            mode: mode,
            currentUserID: nil,
            geocoder: geocoder,
            addressGeocodeDebounce: 0,
            onFinish: { result in
                spy.lastResult = result
            }
        )
        presenter.interactor = fake
        return (presenter, fake, spy)
    }

    private final class ImmediateSuccessGeocoder: AddressGeocoderProtocol {
        func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, AddressGeocoderError>) -> Void) {
            let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(.emptyQuery))
                }
                return
            }
            DispatchQueue.main.async {
                completion(.success(CLLocationCoordinate2D(latitude: 55.75, longitude: 37.62)))
            }
        }
    }
}
