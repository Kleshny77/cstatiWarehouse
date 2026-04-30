package usecase

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func reservationsTestSeed(
	t *testing.T,
	clk *fakeClock,
	userID, orgID uuid.UUID,
	itemQty int,
	itemStatus domain.ItemStatus,
) (*ReservationsUseCase, *fakeReservationRepo, *fakeItemRepo, *fakeMemberRepo, *fakeEventRepo, uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	items := newFakeItemRepo()
	members := newFakeMemberRepo()
	reservations := newFakeReservationRepo()
	events := newFakeEventRepo()

	if err := members.Add(ctx, &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         userID,
		Role:           domain.OrgRoleMember,
		JoinedAt:       clk.Now(),
	}); err != nil {
		t.Fatalf("seed member: %v", err)
	}

	itemID := uuid.New()
	addr := "Москва"
	err := items.Create(ctx, &domain.Item{
		ID:              itemID,
		OrganizationID:  orgID,
		HeldByUserID:    userID,
		Name:            "Товар",
		CategoryName:    "Кат",
		Quantity:        itemQty,
		Status:          itemStatus,
		LocationAddress: &addr,
		MeasureUnit:     domain.MeasureUnitPiece,
		CreatedAt:       clk.Now(),
		UpdatedAt:       clk.Now(),
	})
	if err != nil {
		t.Fatalf("seed item: %v", err)
	}

	uc := NewReservationsUseCase(reservations, items, members, events, clk)
	return uc, reservations, items, members, events, itemID
}

func TestReservationsUseCase_Create_ValidationAndAccess(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	userID := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, _, itemID := reservationsTestSeed(t, clk, userID, orgID, 5, domain.ItemStatusInStock)

	ctx := context.Background()

	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 0,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("quantity 0: want ErrValidation, got %v", err)
	}

	longNotes := strings.Repeat("n", reservationNotesMaxLen+1)
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 1, Notes: longNotes,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("long notes: want ErrValidation, got %v", err)
	}

	past := clk.Now().Add(-time.Hour)
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 1, ExpiresAt: &past,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("past expiry: want ErrValidation, got %v", err)
	}

	far := clk.Now().Add(reservationMaxFutureExpiry + time.Hour)
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 1, ExpiresAt: &far,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("far expiry: want ErrValidation, got %v", err)
	}

	missingItem := uuid.New()
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: missingItem, Quantity: 1,
	}); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("missing item: want ErrNotFound, got %v", err)
	}

	stranger := uuid.New()
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: stranger, ItemID: itemID, Quantity: 1,
	}); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("non-member: want ErrForbidden, got %v", err)
	}

	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 10,
	}); !errors.Is(err, domain.ErrConflict) {
		t.Fatalf("qty > stock: want ErrConflict, got %v", err)
	}
}

func TestReservationsUseCase_Create_WithEvent(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	userID := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, events, itemID := reservationsTestSeed(t, clk, userID, orgID, 10, domain.ItemStatusInStock)
	ctx := context.Background()

	evOtherOrg := uuid.New()
	if err := events.Create(ctx, &domain.Event{
		ID:             evOtherOrg,
		OrganizationID: uuid.New(),
		Name:           "Чужое",
		CreatedByID:    userID,
		CreatedAt:      clk.Now(),
		UpdatedAt:      clk.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 1, EventID: &evOtherOrg,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("wrong org event: want ErrValidation, got %v", err)
	}

	evOK := uuid.New()
	if err := events.Create(ctx, &domain.Event{
		ID:             evOK,
		OrganizationID: orgID,
		Name:           "Наше",
		CreatedByID:    userID,
		CreatedAt:      clk.Now(),
		UpdatedAt:      clk.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	res, err := uc.Create(ctx, CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 2, EventID: &evOK,
	})
	if err != nil {
		t.Fatalf("create with event: %v", err)
	}
	if res.EventID == nil || *res.EventID != evOK {
		t.Fatalf("event id not stored: %+v", res.EventID)
	}
}

func TestReservationsUseCase_Create_ArchivedItem(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	userID := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, _, itemID := reservationsTestSeed(t, clk, userID, orgID, 3, domain.ItemStatusArchived)

	if _, err := uc.Create(context.Background(), CreateReservationInput{
		ActorID: userID, ItemID: itemID, Quantity: 1,
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("archived item: want ErrValidation, got %v", err)
	}
}

func TestReservationsUseCase_FulfillAndCancel(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	owner := uuid.New()
	orgID := uuid.New()
	uc, repo, _, _, _, itemID := reservationsTestSeed(t, clk, owner, orgID, 10, domain.ItemStatusInStock)
	ctx := context.Background()

	res, err := uc.Create(ctx, CreateReservationInput{
		ActorID: owner, ItemID: itemID, Quantity: 4,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	stranger := uuid.New()
	if _, err := uc.Fulfill(ctx, stranger, res.ID); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("fulfill stranger: want ErrForbidden, got %v", err)
	}

	done, err := uc.Fulfill(ctx, owner, res.ID)
	if err != nil {
		t.Fatalf("fulfill: %v", err)
	}
	if done.Status != domain.ReservationStatusFulfilled {
		t.Fatalf("status: %+v", done.Status)
	}

	res2, err := uc.Create(ctx, CreateReservationInput{
		ActorID: owner, ItemID: itemID, Quantity: 2,
	})
	if err != nil {
		t.Fatalf("create2: %v", err)
	}

	if _, err := uc.Cancel(ctx, CancelReservationInput{
		ActorID: owner, ReservationID: res2.ID, CancellationReason: strings.Repeat("x", reservationCancelReasonMaxLen+1),
	}); !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("long cancel reason: want ErrValidation, got %v", err)
	}

	cancelled, err := uc.Cancel(ctx, CancelReservationInput{
		ActorID: owner, ReservationID: res2.ID, CancellationReason: "не нужно",
	})
	if err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if cancelled.Status != domain.ReservationStatusCancelled {
		t.Fatalf("cancel status: %+v", cancelled.Status)
	}

	stored, err := repo.FindByID(ctx, res2.ID)
	if err != nil || stored.Status != domain.ReservationStatusCancelled {
		t.Fatalf("repo after cancel: %+v err=%v", stored, err)
	}
}

func TestReservationsUseCase_GetAvailableQuantity(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	owner := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, _, itemID := reservationsTestSeed(t, clk, owner, orgID, 10, domain.ItemStatusInStock)
	ctx := context.Background()

	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: owner, ItemID: itemID, Quantity: 4,
	}); err != nil {
		t.Fatal(err)
	}

	total, reserved, avail, err := uc.GetAvailableQuantity(ctx, owner, itemID)
	if err != nil {
		t.Fatal(err)
	}
	if total != 10 || reserved != 4 || avail != 6 {
		t.Fatalf("availability: total=%d reserved=%d avail=%d", total, reserved, avail)
	}
}

func TestReservationsUseCase_ListByItem_Forbidden(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	owner := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, _, itemID := reservationsTestSeed(t, clk, owner, orgID, 5, domain.ItemStatusInStock)

	if _, err := uc.ListByItem(context.Background(), uuid.New(), itemID, nil); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("list stranger: want ErrForbidden, got %v", err)
	}
}

func TestReservationsUseCase_ExpireDueReservations(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	owner := uuid.New()
	orgID := uuid.New()
	uc, _, _, _, _, itemID := reservationsTestSeed(t, clk, owner, orgID, 10, domain.ItemStatusInStock)
	ctx := context.Background()

	exp := clk.Now().Add(time.Hour)
	if _, err := uc.Create(ctx, CreateReservationInput{
		ActorID: owner, ItemID: itemID, Quantity: 1, ExpiresAt: &exp,
	}); err != nil {
		t.Fatal(err)
	}
	clk.Advance(2 * time.Hour)

	res, err := uc.ExpireDueReservations(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if res.Scanned != 1 || res.Expired != 1 || res.Failed != 0 {
		t.Fatalf("expire result: %+v", res)
	}
}
