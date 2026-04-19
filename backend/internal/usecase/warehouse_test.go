package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func newWarehouseUC(t *testing.T) (*WarehouseUseCase, *fakeItemRepo, *fakeClock) {
	t.Helper()
	items := newFakeItemRepo()
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))
	return NewWarehouseUseCase(items, clock), items, clock
}

func TestWarehouseUseCase_Create(t *testing.T) {
	uc, _, _ := newWarehouseUC(t)
	owner := uuid.New()

	item, err := uc.Create(context.Background(), CreateItemInput{
		OwnerID: owner, Name: "Кола", CategoryName: "Напитки", Quantity: 3,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if item.OwnerID != owner || item.Quantity != 3 || item.Status != domain.ItemStatusInStock {
		t.Errorf("unexpected item: %+v", item)
	}

	if _, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "", Quantity: 1}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for empty name, got %v", err)
	}
	if _, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "x", Quantity: -1}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for negative quantity, got %v", err)
	}
}

func TestWarehouseUseCase_Update_OnlyOwner(t *testing.T) {
	uc, _, _ := newWarehouseUC(t)
	owner := uuid.New()
	other := uuid.New()

	created, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	_, err = uc.Update(context.Background(), UpdateItemInput{ID: created.ID, OwnerID: other, Name: "B", Quantity: 1})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for other owner, got %v", err)
	}

	updated, err := uc.Update(context.Background(), UpdateItemInput{ID: created.ID, OwnerID: owner, Name: "B", Quantity: 5})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if updated.Name != "B" || updated.Quantity != 5 {
		t.Errorf("update not applied: %+v", updated)
	}
}

func TestWarehouseUseCase_Archive_FullAndValidation(t *testing.T) {
	uc, _, clock := newWarehouseUC(t)
	owner := uuid.New()
	created, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, OwnerID: owner, Quantity: 1, Reason: "boom"})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for bogus reason, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, OwnerID: owner, Quantity: 0, Reason: domain.ArchiveReasonExpired})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for zero quantity, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, OwnerID: owner, Quantity: 999, Reason: domain.ArchiveReasonExpired})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for over-quantity, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, OwnerID: owner, Quantity: 1, Reason: domain.ArchiveReasonUsedAtEvent})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for 'usedAtEvent' without detail, got %v", err)
	}

	clock.Advance(time.Minute)
	archived, event, err := uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: created.ID, OwnerID: owner, Quantity: 1, Reason: domain.ArchiveReasonExpired,
	})
	if err != nil {
		t.Fatalf("archive failed: %v", err)
	}
	if archived.Status != domain.ItemStatusArchived {
		t.Errorf("status must be archived, got %s", archived.Status)
	}
	if archived.Quantity != 0 {
		t.Errorf("quantity must be 0 after full archive, got %d", archived.Quantity)
	}
	if event == nil || event.Quantity != 1 || event.Reason != domain.ArchiveReasonExpired {
		t.Errorf("unexpected event: %+v", event)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: created.ID, OwnerID: owner, Quantity: 1, Reason: domain.ArchiveReasonLost,
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("already archived item must reject further archive, got %v", err)
	}
}

func TestWarehouseUseCase_Archive_PartialKeepsInStock(t *testing.T) {
	uc, _, _ := newWarehouseUC(t)
	owner := uuid.New()
	created, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "Болт", Quantity: 10})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	updated, event, err := uc.Archive(context.Background(), ArchiveItemInput{
		ItemID:       created.ID,
		OwnerID:      owner,
		Quantity:     3,
		Reason:       domain.ArchiveReasonUsedAtEvent,
		ReasonDetail: "Хакатон",
	})
	if err != nil {
		t.Fatalf("partial archive failed: %v", err)
	}
	if updated.Status != domain.ItemStatusInStock {
		t.Errorf("partial archive must keep in_stock, got %s", updated.Status)
	}
	if updated.Quantity != 7 {
		t.Errorf("quantity must be 7 after -3, got %d", updated.Quantity)
	}
	if event.Quantity != 3 || event.ReasonDetail != "Хакатон" {
		t.Errorf("unexpected event: %+v", event)
	}

	events, err := uc.ListArchiveEvents(context.Background(), owner)
	if err != nil {
		t.Fatalf("list events failed: %v", err)
	}
	if len(events) != 1 {
		t.Errorf("expected 1 event, got %d", len(events))
	}
}

func TestWarehouseUseCase_Delete_OnlyOwner(t *testing.T) {
	uc, repo, _ := newWarehouseUC(t)
	owner := uuid.New()
	other := uuid.New()

	created, err := uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	if err := uc.Delete(context.Background(), created.ID, other); !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for other owner, got %v", err)
	}
	if err := uc.Delete(context.Background(), created.ID, owner); err != nil {
		t.Fatalf("delete failed: %v", err)
	}
	if _, ok := repo.items[created.ID]; ok {
		t.Error("item must be gone from repo")
	}
}

func TestWarehouseUseCase_ListAndCategories(t *testing.T) {
	uc, _, clock := newWarehouseUC(t)
	owner := uuid.New()
	other := uuid.New()

	_, _ = uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "Кола", CategoryName: "Напитки", Quantity: 1})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{OwnerID: owner, Name: "Пицца", CategoryName: "Еда", Quantity: 2})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{OwnerID: other, Name: "Чужое", CategoryName: "Прочее", Quantity: 1})

	list, err := uc.List(context.Background(), owner, ItemFilter{})
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 items for owner, got %d", len(list))
	}

	inStock := domain.ItemStatusInStock
	onlyInStock, err := uc.List(context.Background(), owner, ItemFilter{Status: &inStock})
	if err != nil {
		t.Fatalf("filtered list failed: %v", err)
	}
	if len(onlyInStock) != 2 {
		t.Errorf("expected 2 in_stock items, got %d", len(onlyInStock))
	}

	archived := domain.ItemStatusArchived
	onlyArchived, err := uc.List(context.Background(), owner, ItemFilter{Status: &archived})
	if err != nil {
		t.Fatalf("filtered list failed: %v", err)
	}
	if len(onlyArchived) != 0 {
		t.Errorf("expected 0 archived items, got %d", len(onlyArchived))
	}

	cats, err := uc.Categories(context.Background(), owner)
	if err != nil {
		t.Fatalf("categories failed: %v", err)
	}
	if len(cats) != 2 || cats[0] != "Еда" || cats[1] != "Напитки" {
		t.Errorf("unexpected categories: %+v", cats)
	}
}
