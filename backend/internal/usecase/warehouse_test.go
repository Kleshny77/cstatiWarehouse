package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// newWarehouseUC настраивает WarehouseUseCase с одним пользователем,
// который является member одной организации. Возвращает use-case, моки,
// id пользователя и id организации, чтобы в тестах не городить каждый раз.
func newWarehouseUC(t *testing.T) (*WarehouseUseCase, *fakeItemRepo, *fakeMemberRepo, *fakeClock, uuid.UUID, uuid.UUID) {
	t.Helper()
	items := newFakeItemRepo()
	members := newFakeMemberRepo()
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))

	orgID := uuid.New()
	userID := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         userID,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       clock.Now(),
	}); err != nil {
		t.Fatalf("failed to seed membership: %v", err)
	}
	return NewWarehouseUseCase(items, members, clock), items, members, clock, userID, orgID
}

func TestWarehouseUseCase_Create(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)

	item, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Кола", CategoryName: "Напитки", Quantity: 3,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if item.OrganizationID != orgID || item.HeldByUserID != userID || item.Quantity != 3 || item.Status != domain.ItemStatusInStock {
		t.Errorf("unexpected item: %+v", item)
	}

	if _, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "", Quantity: 1}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for empty name, got %v", err)
	}
	if _, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "x", Quantity: -1}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for negative quantity, got %v", err)
	}

	// Попытка создать айтем в организации, в которой юзер не состоит, — forbidden.
	stranger := uuid.New()
	if _, err := uc.Create(context.Background(), CreateItemInput{UserID: stranger, OrganizationID: orgID, Name: "A", Quantity: 1}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden for non-member create, got %v", err)
	}
}

func TestWarehouseUseCase_Update_OnlyMembers(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)
	other := uuid.New()

	created, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	// Чужой юзер не видит айтем → NotFound (не раскрываем существование).
	_, err = uc.Update(context.Background(), UpdateItemInput{ID: created.ID, UserID: other, Name: "B", Quantity: 1})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for non-member update, got %v", err)
	}

	updated, err := uc.Update(context.Background(), UpdateItemInput{ID: created.ID, UserID: userID, Name: "B", Quantity: 5})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if updated.Name != "B" || updated.Quantity != 5 {
		t.Errorf("update not applied: %+v", updated)
	}
}

func TestWarehouseUseCase_Archive_FullAndValidation(t *testing.T) {
	uc, _, _, clock, userID, orgID := newWarehouseUC(t)
	created, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, UserID: userID, Quantity: 1, Reason: "boom"})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for bogus reason, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, UserID: userID, Quantity: 0, Reason: domain.ArchiveReasonExpired})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for zero quantity, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, UserID: userID, Quantity: 999, Reason: domain.ArchiveReasonExpired})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for over-quantity, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{ItemID: created.ID, UserID: userID, Quantity: 1, Reason: domain.ArchiveReasonUsedAtEvent})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for 'usedAtEvent' without detail, got %v", err)
	}

	clock.Advance(time.Minute)
	archived, event, err := uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: created.ID, UserID: userID, Quantity: 1, Reason: domain.ArchiveReasonExpired,
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
	if event == nil || event.Quantity != 1 || event.Reason != domain.ArchiveReasonExpired || event.OrganizationID != orgID || event.ArchivedByUserID != userID {
		t.Errorf("unexpected event: %+v", event)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: created.ID, UserID: userID, Quantity: 1, Reason: domain.ArchiveReasonLost,
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("already archived item must reject further archive, got %v", err)
	}
}

func TestWarehouseUseCase_Archive_PartialKeepsInStock(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)
	created, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "Болт", Quantity: 10})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	updated, event, err := uc.Archive(context.Background(), ArchiveItemInput{
		ItemID:       created.ID,
		UserID:       userID,
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

	events, err := uc.ListArchiveEvents(context.Background(), userID, orgID)
	if err != nil {
		t.Fatalf("list events failed: %v", err)
	}
	if len(events) != 1 {
		t.Errorf("expected 1 event, got %d", len(events))
	}
}

func TestWarehouseUseCase_Delete_OnlyMembers(t *testing.T) {
	uc, repo, _, _, userID, orgID := newWarehouseUC(t)
	other := uuid.New()

	created, err := uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	if err := uc.Delete(context.Background(), created.ID, other); !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for non-member, got %v", err)
	}
	if err := uc.Delete(context.Background(), created.ID, userID); err != nil {
		t.Fatalf("delete failed: %v", err)
	}
	if _, ok := repo.items[created.ID]; ok {
		t.Error("item must be gone from repo")
	}
}

func TestWarehouseUseCase_ListAndCategories(t *testing.T) {
	uc, _, members, clock, userID, orgID := newWarehouseUC(t)

	// Вторая организация с другим пользователем (для изоляции).
	otherOrg := uuid.New()
	otherUser := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: otherOrg,
		UserID:         otherUser,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       clock.Now(),
	}); err != nil {
		t.Fatalf("seed other org failed: %v", err)
	}

	_, _ = uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "Кола", CategoryName: "Напитки", Quantity: 1})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{UserID: userID, OrganizationID: orgID, Name: "Пицца", CategoryName: "Еда", Quantity: 2})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{UserID: otherUser, OrganizationID: otherOrg, Name: "Чужое", CategoryName: "Прочее", Quantity: 1})

	list, err := uc.List(context.Background(), userID, orgID, ItemFilter{})
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 items for org, got %d", len(list))
	}

	inStock := domain.ItemStatusInStock
	onlyInStock, err := uc.List(context.Background(), userID, orgID, ItemFilter{Status: &inStock})
	if err != nil {
		t.Fatalf("filtered list failed: %v", err)
	}
	if len(onlyInStock) != 2 {
		t.Errorf("expected 2 in_stock items, got %d", len(onlyInStock))
	}

	archived := domain.ItemStatusArchived
	onlyArchived, err := uc.List(context.Background(), userID, orgID, ItemFilter{Status: &archived})
	if err != nil {
		t.Fatalf("filtered list failed: %v", err)
	}
	if len(onlyArchived) != 0 {
		t.Errorf("expected 0 archived items, got %d", len(onlyArchived))
	}

	cats, err := uc.Categories(context.Background(), userID, orgID)
	if err != nil {
		t.Fatalf("categories failed: %v", err)
	}
	if len(cats) != 2 || cats[0] != "Еда" || cats[1] != "Напитки" {
		t.Errorf("unexpected categories: %+v", cats)
	}

	// Попытка получить список чужой организации → forbidden.
	if _, err := uc.List(context.Background(), userID, otherOrg, ItemFilter{}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden for non-member list, got %v", err)
	}
}
