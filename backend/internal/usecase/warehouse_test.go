package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

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
		LocationAddress: addrPtr("Москва, тестовый адрес"),
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

	stranger := uuid.New()
	if _, err := uc.Create(context.Background(), CreateItemInput{
		UserID: stranger, OrganizationID: orgID, Name: "A", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden for non-member create, got %v", err)
	}

	if _, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Без адреса", CategoryName: "X", Quantity: 1,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation for missing location_address, got %v", err)
	}
}

func TestWarehouseUseCase_Update_OnlyMembers(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)
	other := uuid.New()

	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	_, err = uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{UserID: other, Name: "B", Quantity: 1}))
	if !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for non-member update, got %v", err)
	}

	updated, err := uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{UserID: userID, Name: "B", Quantity: 5}))
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if updated.Name != "B" || updated.Quantity != 5 {
		t.Errorf("update not applied: %+v", updated)
	}
}

func TestWarehouseUseCase_CreateAndUpdate_LocationAddress(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)

	addr := "  ул. Пушкина, 10  "
	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID:          userID,
		OrganizationID:  orgID,
		Name:            "A",
		Quantity:        1,
		LocationAddress: &addr,
	})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	if created.LocationAddress == nil || *created.LocationAddress != "ул. Пушкина, 10" {
		t.Fatalf("expected trimmed address, got %+v", created.LocationAddress)
	}

	empty := "   "
	_, err = uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{
		UserID:          userID,
		Name:            "A",
		Quantity:        1,
		LocationAddress: &empty,
	}))
	if !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("expected ErrValidation when clearing location_address, got %v", err)
	}

	next := "Москва, ул. Новый Арбат, 15"
	updated, err := uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{
		UserID:          userID,
		Name:            "A",
		Quantity:        1,
		LocationAddress: &next,
	}))
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if updated.LocationAddress == nil || *updated.LocationAddress != next {
		t.Fatalf("unexpected address after update: %+v", updated.LocationAddress)
	}
}

func TestWarehouseUseCase_Archive_FullAndValidation(t *testing.T) {
	uc, _, _, clock, userID, orgID := newWarehouseUC(t)
	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
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
	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Болт", Quantity: 10,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
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

	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "A", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
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

	_, _ = uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Кола", CategoryName: "Напитки", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Пицца", CategoryName: "Еда", Quantity: 2,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	clock.Advance(time.Second)
	_, _ = uc.Create(context.Background(), CreateItemInput{
		UserID: otherUser, OrganizationID: otherOrg, Name: "Чужое", CategoryName: "Прочее", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})

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

	if _, err := uc.List(context.Background(), userID, otherOrg, ItemFilter{}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden for non-member list, got %v", err)
	}
}

func TestWarehouseUseCase_CreateLiterWithoutVolumeOK(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)
	item, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Сок", CategoryName: "Напитки", Quantity: 12,
		MeasureUnit:     string(domain.MeasureUnitLiter),
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("expected liter item create: %v", err)
	}
	if item.VolumePerUnit != nil {
		t.Fatalf("volume_per_unit must be nil (defaults to 1 L per package)")
	}
	if item.MeasureUnit != domain.MeasureUnitLiter || item.Quantity != 12 {
		t.Fatalf("unexpected item: %+v", item)
	}
}

func TestWarehouseUseCase_CreateVariantAndArchiveParentBlocked(t *testing.T) {
	uc, _, _, _, userID, orgID := newWarehouseUC(t)
	parent, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Сок", CategoryName: "Напитки", Quantity: 0,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("create parent: %v", err)
	}
	sevenHundredML := 700.0
	child, err := uc.Create(context.Background(), CreateItemInput{
		UserID: userID, OrganizationID: orgID, Name: "Сок", CategoryName: "Напитки", Quantity: 10,
		ParentItemID: &parent.ID, VariantLabel: "0,7 л", MeasureUnit: string(domain.MeasureUnitMilliliter),
		VolumePerUnit:   &sevenHundredML,
		LocationAddress: addrPtr("Москва, склад Б"),
	})
	if err != nil {
		t.Fatalf("create variant: %v", err)
	}
	if child.ParentItemID == nil || *child.ParentItemID != parent.ID {
		t.Fatalf("expected parent link on variant")
	}
	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: parent.ID, UserID: userID, Quantity: 1, Reason: domain.ArchiveReasonDisposed, ReasonDetail: "x",
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("expected ErrValidation when archiving parent while children have stock, got %v", err)
	}
}

func TestWarehouseUseCase_List_MemberSeesAllItems_FilterByHeldOptional(t *testing.T) {
	uc, _, members, clock, ownerID, orgID := newWarehouseUC(t)

	memberID := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         memberID,
		Role:           domain.OrgRoleMember,
		JoinedAt:       clock.Now(),
	}); err != nil {
		t.Fatalf("seed member failed: %v", err)
	}

	_, err := uc.Create(context.Background(), CreateItemInput{
		UserID: ownerID, OrganizationID: orgID, Name: "Кола", CategoryName: "Напитки", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("create owner item: %v", err)
	}
	clock.Advance(time.Second)
	held := memberID
	_, err = uc.Create(context.Background(), CreateItemInput{
		UserID: ownerID, OrganizationID: orgID, HeldByUserID: &held,
		Name: "Пицца", CategoryName: "Еда", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("create member item: %v", err)
	}

	memberList, err := uc.List(context.Background(), memberID, orgID, ItemFilter{})
	if err != nil {
		t.Fatalf("member list failed: %v", err)
	}
	if len(memberList) != 2 {
		t.Errorf("member must see all org items without filter, got %d", len(memberList))
	}

	filterOwner := ownerID
	byOwnerHeld, err := uc.List(context.Background(), memberID, orgID, ItemFilter{HeldByUserID: &filterOwner})
	if err != nil {
		t.Fatalf("member filtered list failed: %v", err)
	}
	if len(byOwnerHeld) != 1 || byOwnerHeld[0].Name != "Кола" {
		t.Errorf("HeldByUserID filter must scope to owner's holdings, got %+v", byOwnerHeld)
	}

	filterMember := memberID
	memberMine, err := uc.List(context.Background(), memberID, orgID, ItemFilter{HeldByUserID: &filterMember})
	if err != nil {
		t.Fatalf("member mine list failed: %v", err)
	}
	if len(memberMine) != 1 || memberMine[0].Name != "Пицца" {
		t.Errorf("member mine list unexpected: %+v", memberMine)
	}

	ownerList, err := uc.List(context.Background(), ownerID, orgID, ItemFilter{})
	if err != nil {
		t.Fatalf("owner list failed: %v", err)
	}
	if len(ownerList) != 2 {
		t.Errorf("owner must see all org items, got %d", len(ownerList))
	}

	uid := ownerID
	ownerMine, err := uc.List(context.Background(), ownerID, orgID, ItemFilter{HeldByUserID: &uid})
	if err != nil {
		t.Fatalf("owner mine list failed: %v", err)
	}
	if len(ownerMine) != 1 || ownerMine[0].Name != "Кола" {
		t.Errorf("owner mine list unexpected: %+v", ownerMine)
	}
}

func TestWarehouseUseCase_MemberCannotMutateWarehouse(t *testing.T) {
	uc, _, members, _, ownerID, orgID := newWarehouseUC(t)

	memberID := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         memberID,
		Role:           domain.OrgRoleMember,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("seed member failed: %v", err)
	}

	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID: ownerID, OrganizationID: orgID, Name: "A", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	if _, err := uc.Create(context.Background(), CreateItemInput{
		UserID: memberID, OrganizationID: orgID, Name: "X", Quantity: 1,
		LocationAddress: addrPtr("Москва, тестовый адрес"),
	}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member create: want ErrForbidden, got %v", err)
	}

	_, err = uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{
		UserID: memberID, Name: "B", Quantity: 1,
	}))
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member update: want ErrForbidden, got %v", err)
	}

	_, _, err = uc.Archive(context.Background(), ArchiveItemInput{
		ItemID: created.ID, UserID: memberID, Quantity: 1, Reason: domain.ArchiveReasonExpired,
	})
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member archive: want ErrForbidden, got %v", err)
	}

	if err := uc.Delete(context.Background(), created.ID, memberID); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member delete: want ErrForbidden, got %v", err)
	}
}

func TestWarehouseUseCase_Update_ExpectedUpdatedAt_Conflict(t *testing.T) {
	uc, _, _, clock, userID, orgID := newWarehouseUC(t)
	created, err := uc.Create(context.Background(), CreateItemInput{
		UserID:            userID,
		OrganizationID:    orgID,
		Name:              "A",
		Quantity:          1,
		LocationAddress:   addrPtr("Москва"),
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	stale := created.UpdatedAt
	clock.Advance(time.Millisecond)

	first, err := uc.Update(context.Background(), mergeItemUpdate(created, UpdateItemInput{
		UserID:            userID,
		Name:              "B",
		Quantity:          1,
		ExpectedUpdatedAt: &stale,
	}))
	if err != nil {
		t.Fatalf("update with matching version: %v", err)
	}
	_ = first

	_, err = uc.Update(context.Background(), mergeItemUpdate(first, UpdateItemInput{
		UserID:            userID,
		Name:              "C",
		Quantity:          1,
		ExpectedUpdatedAt: &stale,
	}))
	var conflict *domain.ItemVersionConflictError
	if !errors.As(err, &conflict) {
		t.Fatalf("expected *ItemVersionConflictError, got %v", err)
	}
	if conflict.ServerItem.Name != "B" {
		t.Errorf("server truth: want name B, got %q", conflict.ServerItem.Name)
	}
}

func addrPtr(s string) *string {
	return &s
}

func mergeItemUpdate(base *domain.Item, patch UpdateItemInput) UpdateItemInput {
	p := patch
	p.ID = base.ID
	if p.Description == "" {
		p.Description = base.Description
	}
	if p.CategoryName == "" {
		p.CategoryName = base.CategoryName
	}
	if p.LocationAddress == nil {
		p.LocationAddress = cloneStrPtr(base.LocationAddress)
	}
	if p.VariantLabel == "" {
		p.VariantLabel = base.VariantLabel
	}
	if p.MeasureUnit == "" {
		p.MeasureUnit = string(base.MeasureUnit)
	}
	if p.ExpirationDate == nil {
		p.ExpirationDate = base.ExpirationDate
	}
	if p.ImageURL == nil {
		p.ImageURL = base.ImageURL
	}
	if p.VolumePerUnit == nil {
		p.VolumePerUnit = base.VolumePerUnit
	}
	return p
}

func cloneStrPtr(src *string) *string {
	if src == nil {
		return nil
	}
	s := *src
	return &s
}
