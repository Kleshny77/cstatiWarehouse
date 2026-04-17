//
//  ItemEditPresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

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
        
        #expect(sut.errorMessage == "Укажите категорию")
        #expect(fake.saveCalls.isEmpty)
    }
    
    @Test
    func saveButtonTapped_withInvalidQuantity_setsError() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "x"
        sut.draft.quantity = 0
        
        sut.saveButtonTapped()
        
        #expect(sut.errorMessage == "Количество должно быть не меньше 1")
        #expect(fake.saveCalls.isEmpty)
    }
    
    @Test
    func saveButtonTapped_create_buildsItemAndCallsInteractorAsNew() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "  пиво  "
        sut.draft.description = "  светлое  "
        sut.draft.quantity = 3
        sut.draft.hasShelfLife = false
        
        sut.saveButtonTapped()
        
        #expect(sut.isSaving == true)
        #expect(fake.saveCalls.count == 1)
        let (item, isNew) = fake.saveCalls[0]
        #expect(isNew == true)
        #expect(item.name == "пиво")
        #expect(item.description == "светлое")
        #expect(item.categoryName == "cat")
        #expect(item.quantity == 3)
        #expect(item.expirationDate == nil)
        #expect(item.status == .inStock)
    }
    
    @Test
    func saveButtonTapped_emptyDescription_producesNilDescription() {
        let (sut, fake, _) = makeSUT(mode: .create(suggestedCategory: "cat"))
        sut.draft.name = "x"
        sut.draft.description = "   "
        
        sut.saveButtonTapped()
        
        #expect(fake.saveCalls.first?.0.description == nil)
    }
    
    @Test
    func saveButtonTapped_edit_preservesIdAndCreatedAtAndStatus() {
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
        
        sut.saveButtonTapped()
        
        let (item, isNew) = fake.saveCalls[0]
        #expect(isNew == false)
        #expect(item.id == original.id)
        #expect(item.createdAt == original.createdAt)
        #expect(item.status == original.status)
        #expect(item.name == "edited")
    }
    
    @Test
    func saved_callsOnFinishWithSavedItem_andClearsSaving() {
        let (sut, _, spy) = makeSUT(mode: .create(suggestedCategory: "c"))
        sut.draft.name = "x"
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
    func failed_setsErrorMessage_andDoesNotFinish() {
        let (sut, _, spy) = makeSUT(mode: .create(suggestedCategory: "c"))
        sut.draft.name = "x"
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
    
    // MARK: Helpers
    
    private final class OnFinishSpy: @unchecked Sendable {
        var lastResult: ItemEditResult?
    }
    
    private func makeSUT(
        mode: ItemEditMode
    ) -> (ItemEditPresenter, FakeItemEditInteractor, OnFinishSpy) {
        let spy = OnFinishSpy()
        let fake = FakeItemEditInteractor()
        let presenter = ItemEditPresenter(mode: mode, onFinish: { result in
            spy.lastResult = result
        })
        presenter.interactor = fake
        return (presenter, fake, spy)
    }
}
