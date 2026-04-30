//
//  MyWarehousePresenterTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

@MainActor
struct MyWarehousePresenterTests {
    @Test
    func viewDidLoad_setsLoadingAndCallsInteractor() {
        let (sut, fake) = makeSUT()
        
        sut.viewDidLoad()
        
        #expect(sut.isLoading == true)
        #expect(fake.resolveActiveOrganizationCallCount == 1)
    }
    
    @Test
    func itemsLoaded_buildsSectionsGroupedByCategory_andExcludesArchived() {
        let (sut, _) = makeSUT()
        let a = makeItem(name: "пиво", category: "напитки")
        let b = makeItem(name: "водка", category: "напитки")
        let c = makeItem(name: "хлеб", category: "еда")
        let archived = makeItem(
            name: "старый хлеб",
            category: "еда",
            status: .archived(reason: .expired, at: .now)
        )
        
        sut.itemsLoaded([a, b, c, archived], scope: .mine)
        
        #expect(sut.isLoading == false)
        #expect(sut.totalItemsCount == 3)
        #expect(sut.sections.map(\.name) == ["еда", "напитки"])
        #expect(sut.sections[0].items.map(\.name) == ["хлеб"])
        #expect(Set(sut.sections[1].items.map(\.name)) == ["пиво", "водка"])
    }
    
    @Test
    func searchText_filtersByNameAndDescription_caseInsensitive() {
        let (sut, _) = makeSUT()
        let a = makeItem(name: "Пиво", description: "светлое", category: "напитки")
        let b = makeItem(name: "Водка", description: "крепкая", category: "напитки")
        sut.itemsLoaded([a, b], scope: .mine)
        
        sut.searchText = "КРЕП"
        
        #expect(sut.totalItemsCount == 1)
        #expect(sut.sections.first?.items.first?.name == "Водка")
    }
    
    @Test
    func addButtonTapped_setsCreateEditPresentation() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        sut.addButtonTapped()
        guard case .create(let suggested) = sut.editPresentation?.mode else {
            Issue.record("Expected .create, got \(String(describing: sut.editPresentation?.mode))")
            return
        }
        #expect(suggested == nil)
    }
    
    @Test
    func editItemRequested_setsEditPresentationForItem() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        let item = makeItem(name: "x", category: "y")

        sut.editItemRequested(item)

        guard case .edit(let captured) = sut.editPresentation?.mode else {
            Issue.record("Expected .edit mode")
            return
        }
        #expect(captured.id == item.id)
    }

    @Test
    func memberRole_canCreateItems_cannotMutateUnheldItems() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary(role: .member)
        let item = makeItem(name: "x", category: "y")

        sut.addButtonTapped()
        #expect(sut.editPresentation != nil)

        sut.editPresentation = nil
        sut.editItemRequested(item)
        #expect(sut.editPresentation == nil)

        sut.archiveItemRequested(item)
        #expect(sut.archivePresentation == nil)

        sut.hardDeleteRequested(item)
        #expect(sut.deleteConfirmation == nil)
    }
    
    @Test
    func archiveItemRequested_setsArchivePresentation() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        let item = makeItem(name: "x", category: "y")

        sut.archiveItemRequested(item)

        #expect(sut.archivePresentation?.item.id == item.id)
    }
    
    @Test
    func confirmArchive_callsInteractor_andClearsPresentation() {
        let (sut, fake) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        let item = makeItem(name: "x", category: "y")
        sut.archiveItemRequested(item)

        sut.confirmArchive(
            decision: ArchiveDecision(quantity: 1, reason: .usedAtEvent, detail: "корпоратив")
        )

        #expect(sut.archivePresentation == nil)
        #expect(fake.archiveCalls.count == 1)
        #expect(fake.archiveCalls.first?.0 == item.id)
        #expect(fake.archiveCalls.first?.1 == 1)
        #expect(fake.archiveCalls.first?.2 == .usedAtEvent)
        #expect(fake.archiveCalls.first?.3 == "корпоратив")
        #expect(fake.archiveCalls.first?.4 == nil)
        #expect(fake.archiveCalls.first?.5 == item.updatedAt)
    }

    @Test
    func confirmArchive_withoutPresentation_doesNothing() {
        let (sut, fake) = makeSUT()

        sut.confirmArchive(
            decision: ArchiveDecision(quantity: 1, reason: .disposed, detail: "")
        )

        #expect(fake.archiveCalls.isEmpty)
    }

    @Test
    func cancelArchive_clearsPresentation() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        sut.archiveItemRequested(makeItem(name: "x", category: "y"))

        sut.cancelArchive()

        #expect(sut.archivePresentation == nil)
    }
    
    @Test
    func hardDeleteFlow_confirmAndCancel() {
        let (sut, fake) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        let item = makeItem(name: "x", category: "y")

        sut.hardDeleteRequested(item)
        #expect(sut.deleteConfirmation?.item.id == item.id)
        
        sut.confirmHardDelete()
        #expect(sut.deleteConfirmation == nil)
        #expect(fake.deleteCalls == [item.id])
        
        sut.hardDeleteRequested(item)
        sut.cancelHardDelete()
        #expect(sut.deleteConfirmation == nil)
        #expect(fake.deleteCalls.count == 1)
    }
    
    @Test
    func itemArchived_removesItemFromSections() {
        let (sut, _) = makeSUT()
        let item = makeItem(name: "x", category: "y")
        sut.itemsLoaded([item], scope: .mine)
        
        var archived = item
        archived.status = .archived(reason: .disposed, at: .now)
        sut.itemArchived(archived)
        
        #expect(sut.totalItemsCount == 0)
        #expect(sut.sections.isEmpty)
    }
    
    @Test
    func itemDeleted_removesFromCache() {
        let (sut, _) = makeSUT()
        let a = makeItem(name: "a", category: "c")
        let b = makeItem(name: "b", category: "c")
        sut.itemsLoaded([a, b], scope: .mine)
        
        sut.itemDeleted(id: a.id)
        
        #expect(sut.totalItemsCount == 1)
        #expect(sut.sections.first?.items.map(\.name) == ["b"])
    }
    
    @Test
    func itemChangedExternally_insertsWhenNew_updatesWhenExisting() {
        let (sut, _) = makeSUT()
        let a = makeItem(name: "a", category: "c")
        sut.itemsLoaded([a], scope: .mine)
        
        let newItem = makeItem(name: "new", category: "c")
        sut.itemChangedExternally(newItem, isNew: true)
        #expect(sut.totalItemsCount == 2)
        
        var updated = a
        updated.name = "a-updated"
        sut.itemChangedExternally(updated, isNew: false)
        let updatedNames = sut.sections.flatMap { $0.items.map(\.name) }
        #expect(updatedNames.contains("a-updated"))
        #expect(!updatedNames.contains("a"))
    }
    
    @Test
    func editCompleted_savedInCreateMode_callsInteractorWithIsNewTrue() {
        let (sut, fake) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        sut.addButtonTapped()
        let item = makeItem(name: "new", category: "c")
        
        sut.editCompleted(result: .saved(item))
        
        #expect(sut.editPresentation == nil)
        #expect(fake.externalChangeCalls.count == 1)
        #expect(fake.externalChangeCalls.first?.0.id == item.id)
        #expect(fake.externalChangeCalls.first?.1 == true)
    }
    
    @Test
    func editCompleted_savedInEditMode_callsInteractorWithIsNewFalse() {
        let (sut, fake) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        let original = makeItem(name: "orig", category: "c")
        sut.itemsLoaded([original], scope: .mine)
        sut.editItemRequested(original)
        
        var edited = original
        edited.name = "edited"
        sut.editCompleted(result: .saved(edited))
        
        #expect(fake.externalChangeCalls.count == 1)
        #expect(fake.externalChangeCalls.first?.1 == false)
    }
    
    @Test
    func editCompleted_cancelled_doesNothing() {
        let (sut, fake) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary()
        sut.addButtonTapped()

        sut.editCompleted(result: .cancelled)
        
        #expect(sut.editPresentation == nil)
        #expect(fake.externalChangeCalls.isEmpty)
    }
    
    @Test
    func itemsLoadFailed_withCachedItems_showsStaleNotice() {
        let (sut, _) = makeSUT()
        sut.itemsLoaded([makeItem(name: "a", category: "c")], scope: .mine)

        sut.itemsLoadFailed(message: "ошибка сети", scope: .mine)

        #expect(sut.passiveNoticeMessage == "Не удалось обновить список. Показаны сохранённые данные.")
    }

    @Test
    func itemsLoadFailed_withoutItems_showsOriginalMessage() {
        let (sut, _) = makeSUT()

        sut.itemsLoadFailed(message: "ошибка сети", scope: .mine)

        #expect(sut.passiveNoticeMessage == "ошибка сети")
    }

    @Test
    func failed_setsErrorMessage_andClearsLoading() {
        let (sut, _) = makeSUT()
        sut.viewDidLoad()
        
        sut.failed(error: "boom")
        
        #expect(sut.isLoading == false)
        #expect(sut.errorMessage == "boom")
    }

    @Test
    func selectScope_suppressesSkeletonUntilCacheMissNotification() {
        let (sut, _) = makeSUT()
        sut.activeOrganization = makeOrganizationSummary(role: .admin)
        sut.itemsLoaded([makeItem(name: "a", category: "c")], scope: .mine)

        sut.selectScope(.all)

        #expect(sut.scope == .all)
        #expect(sut.isAwaitingWarehouseCacheHydration == true)
        #expect(sut.shouldShowSkeleton == false)
        #expect(sut.totalItemsCount == 1)

        sut.warehouseActiveItemsCacheMissed(scope: .all)

        #expect(sut.isAwaitingWarehouseCacheHydration == true)
        #expect(sut.isLoading == true)
        #expect(sut.shouldShowSkeleton == false)
    }

    private func makeSUT() -> (MyWarehousePresenter, FakeMyWarehouseInteractor) {
        let fake = FakeMyWarehouseInteractor()
        let presenter = MyWarehousePresenter()
        presenter.interactor = fake
        fake.presenter = presenter
        return (presenter, fake)
    }

    private func makeOrganizationSummary(role: OrgRole = .admin) -> OrganizationSummary {
        let orgID = UUID()
        return OrganizationSummary(
            organization: Organization(
                id: orgID,
                name: "Test Org",
                ownerID: UUID(),
                isPersonal: false,
                createdAt: .now,
                updatedAt: .now
            ),
            role: role
        )
    }

    private func makeItem(
        name: String,
        description: String? = nil,
        category: String,
        status: ItemStatus = .inStock
    ) -> Item {
        Item(
            name: name,
            description: description,
            categoryName: category,
            quantity: 1,
            status: status
        )
    }
}
