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
    func saveButtonTapped()
    func cancelButtonTapped()
}

@Observable
final class ItemEditPresenter: ItemEditPresenterProtocol {
    // MARK: Properties
    
    var interactor: ItemEditInteractorInputProtocol?
    var router: ItemEditRouterProtocol?
    
    var draft: ItemEditDraft
    var errorMessage: String?
    var isSaving: Bool = false
    var screenTitle: String {
        isNew ? "Новая позиция" : "Редактирование"
    }
    
    private let mode: ItemEditMode
    private let onFinish: (ItemEditResult) -> Void
    
    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }
    
    // MARK: Lifecycle
    
    init(mode: ItemEditMode, onFinish: @escaping (ItemEditResult) -> Void) {
        self.mode = mode
        self.onFinish = onFinish
        switch mode {
        case .create(let suggestedCategory):
            self.draft = .empty(suggestedCategory: suggestedCategory)
        case .edit(let item):
            self.draft = .from(item: item)
        }
    }
    
    // MARK: Public Methods
    
    func viewDidLoad() {
        
    }
    
    func saveButtonTapped() {
        guard validate() else { return }
        
        let item = buildItem()
        isSaving = true
        interactor?.save(item: item, isNew: isNew)
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
            errorMessage = "Укажите категорию"
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
        
        switch mode {
        case .create:
            return Item(
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: draft.quantity,
                expirationDate: expiration,
                createdAt: .now,
                status: .inStock
            )
        case .edit(let original):
            return Item(
                id: original.id,
                name: trimmedName,
                description: description,
                categoryName: trimmedCategory,
                quantity: draft.quantity,
                expirationDate: expiration,
                createdAt: original.createdAt,
                status: original.status
            )
        }
    }
}

// MARK: - ItemEditInteractorOutputProtocol

extension ItemEditPresenter: ItemEditInteractorOutputProtocol {
    func saved(_ item: Item) {
        isSaving = false
        onFinish(.saved(item))
    }
    
    func failed(error: String) {
        isSaving = false
        errorMessage = error
    }
}
