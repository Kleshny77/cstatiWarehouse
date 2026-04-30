package usecase

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type ReservationsUseCase struct {
	repo        ReservationRepository
	itemRepo    ItemRepository
	memberRepo  OrganizationMemberRepository
	eventRepo   EventRepository
	clock       Clock
	broadcaster ReservationBroadcaster
}

func NewReservationsUseCase(
	repo ReservationRepository,
	itemRepo ItemRepository,
	memberRepo OrganizationMemberRepository,
	eventRepo EventRepository,
	clk Clock,
) *ReservationsUseCase {
	return &ReservationsUseCase{
		repo:       repo,
		itemRepo:   itemRepo,
		memberRepo: memberRepo,
		eventRepo:  eventRepo,
		clock:      clk,
	}
}

func (uc *ReservationsUseCase) WithBroadcaster(b ReservationBroadcaster) *ReservationsUseCase {
	uc.broadcaster = b
	return uc
}

const (
	reservationNotesMaxLen        = 2000
	reservationCancelReasonMaxLen = 500
	reservationMaxFutureExpiry    = 365 * 24 * time.Hour
)

type CreateReservationInput struct {
	ActorID   uuid.UUID
	ItemID    uuid.UUID
	Quantity  int
	EventID   *uuid.UUID
	ExpiresAt *time.Time
	Notes     string
}

func (uc *ReservationsUseCase) Create(
	ctx context.Context,
	in CreateReservationInput,
) (*domain.ItemReservation, error) {
	if in.Quantity <= 0 {
		return nil, domain.NewValidationError("quantity must be > 0")
	}
	notes := strings.TrimSpace(in.Notes)
	if len(notes) > reservationNotesMaxLen {
		return nil, domain.NewValidationError("notes is too long")
	}

	now := uc.clock.Now().UTC()
	if in.ExpiresAt != nil {
		exp := in.ExpiresAt.UTC()
		if !exp.After(now) {
			return nil, domain.NewValidationError("expires_at must be in the future")
		}
		if exp.Sub(now) > reservationMaxFutureExpiry {
			return nil, domain.NewValidationError("expires_at is too far in the future")
		}
		in.ExpiresAt = &exp
	}

	item, err := uc.itemRepo.FindByID(ctx, in.ItemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, domain.ErrNotFound
	}
	if item.Status != domain.ItemStatusInStock {
		return nil, domain.NewValidationError("item is archived")
	}
	if in.Quantity > item.Quantity {
		return nil, domain.ErrConflict
	}

	if _, err := uc.memberRepo.FindRole(ctx, item.OrganizationID, in.ActorID); err != nil {
		return nil, domain.ErrForbidden
	}

	if in.EventID != nil && uc.eventRepo != nil {
		ev, err := uc.eventRepo.FindByID(ctx, *in.EventID)
		if err != nil {
			return nil, err
		}
		if ev == nil || ev.OrganizationID != item.OrganizationID {
			return nil, domain.NewValidationError("event not found in organization")
		}
	}

	r := &domain.ItemReservation{
		ID:               uuid.New(),
		ItemID:           item.ID,
		OrganizationID:   item.OrganizationID,
		Quantity:         in.Quantity,
		EventID:          in.EventID,
		ReservedByUserID: in.ActorID,
		ReservedAt:       now,
		ExpiresAt:        in.ExpiresAt,
		Status:           domain.ReservationStatusActive,
		Notes:            notes,
		CreatedAt:        now,
		UpdatedAt:        now,
	}
	if err := uc.repo.Create(ctx, r); err != nil {
		return nil, err
	}

	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastReservationCreated(r.OrganizationID, r)
	}
	return r, nil
}

func (uc *ReservationsUseCase) Fulfill(
	ctx context.Context,
	actorID, reservationID uuid.UUID,
) (*domain.ItemReservation, error) {
	r, err := uc.repo.FindByID(ctx, reservationID)
	if err != nil {
		return nil, err
	}
	if r == nil {
		return nil, domain.ErrNotFound
	}
	isAdmin, err := uc.isAdmin(ctx, r.OrganizationID, actorID)
	if err != nil {
		return nil, err
	}
	if !r.CanBeFulfilledBy(actorID, isAdmin) {
		if r.Status != domain.ReservationStatusActive {
			return nil, domain.NewValidationError("reservation is not active")
		}
		return nil, domain.ErrForbidden
	}

	now := uc.clock.Now().UTC()
	r.Status = domain.ReservationStatusFulfilled
	r.FulfilledAt = &now
	r.FulfilledByUserID = &actorID
	r.UpdatedAt = now

	if err := uc.repo.Update(ctx, r); err != nil {
		return nil, err
	}
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastReservationFulfilled(r.OrganizationID, r)
	}
	return r, nil
}

type CancelReservationInput struct {
	ActorID            uuid.UUID
	ReservationID      uuid.UUID
	CancellationReason string
}

func (uc *ReservationsUseCase) Cancel(
	ctx context.Context,
	in CancelReservationInput,
) (*domain.ItemReservation, error) {
	cancelReason := strings.TrimSpace(in.CancellationReason)
	if len(cancelReason) > reservationCancelReasonMaxLen {
		return nil, domain.NewValidationError("cancellation_reason is too long")
	}

	r, err := uc.repo.FindByID(ctx, in.ReservationID)
	if err != nil {
		return nil, err
	}
	if r == nil {
		return nil, domain.ErrNotFound
	}
	isAdmin, err := uc.isAdmin(ctx, r.OrganizationID, in.ActorID)
	if err != nil {
		return nil, err
	}
	if !r.CanBeCancelledBy(in.ActorID, isAdmin) {
		if r.Status != domain.ReservationStatusActive {
			return nil, domain.NewValidationError("reservation is not active")
		}
		return nil, domain.ErrForbidden
	}

	now := uc.clock.Now().UTC()
	r.Status = domain.ReservationStatusCancelled
	r.CancelledAt = &now
	r.CancelledByUserID = &in.ActorID
	r.CancellationReason = cancelReason
	r.UpdatedAt = now

	if err := uc.repo.Update(ctx, r); err != nil {
		return nil, err
	}
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastReservationCancelled(r.OrganizationID, r)
	}
	return r, nil
}

func (uc *ReservationsUseCase) ListByItem(
	ctx context.Context,
	actorID, itemID uuid.UUID,
	status *domain.ReservationStatus,
) ([]domain.ItemReservation, error) {
	item, err := uc.itemRepo.FindByID(ctx, itemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, domain.ErrNotFound
	}
	if _, err := uc.memberRepo.FindRole(ctx, item.OrganizationID, actorID); err != nil {
		return nil, domain.ErrForbidden
	}
	return uc.repo.ListByItem(ctx, itemID, status)
}

func (uc *ReservationsUseCase) ListByOrganization(
	ctx context.Context,
	actorID, orgID uuid.UUID,
	status *domain.ReservationStatus,
) ([]domain.ItemReservation, error) {
	if _, err := uc.memberRepo.FindRole(ctx, orgID, actorID); err != nil {
		return nil, domain.ErrForbidden
	}
	return uc.repo.ListByOrganization(ctx, orgID, status)
}

func (uc *ReservationsUseCase) GetAvailableQuantity(
	ctx context.Context,
	actorID, itemID uuid.UUID,
) (total, reserved, available int, err error) {
	item, err := uc.itemRepo.FindByID(ctx, itemID)
	if err != nil {
		return 0, 0, 0, err
	}
	if item == nil {
		return 0, 0, 0, domain.ErrNotFound
	}
	if _, err := uc.memberRepo.FindRole(ctx, item.OrganizationID, actorID); err != nil {
		return 0, 0, 0, domain.ErrForbidden
	}
	reserved, err = uc.repo.GetActiveTotalReservedForItem(ctx, itemID)
	if err != nil {
		return 0, 0, 0, err
	}
	available = item.Quantity - reserved
	if available < 0 {
		available = 0
	}
	return item.Quantity, reserved, available, nil
}

type ReservationExpirationTickResult struct {
	Scanned int
	Expired int
	Failed  int
}

func (uc *ReservationsUseCase) ExpireDueReservations(ctx context.Context) (ReservationExpirationTickResult, error) {
	now := uc.clock.Now().UTC()
	due, err := uc.repo.FindExpired(ctx, now)
	if err != nil {
		return ReservationExpirationTickResult{}, err
	}
	res := ReservationExpirationTickResult{Scanned: len(due)}
	for i := range due {
		r := &due[i]
		if !r.IsActive() {
			continue
		}
		r.Status = domain.ReservationStatusExpired
		r.UpdatedAt = now
		if err := uc.repo.Update(ctx, r); err != nil {
			res.Failed++
			continue
		}
		res.Expired++
		if uc.broadcaster != nil {
			uc.broadcaster.BroadcastReservationExpired(r.OrganizationID, r)
		}
	}
	return res, nil
}

func (uc *ReservationsUseCase) isAdmin(ctx context.Context, orgID, userID uuid.UUID) (bool, error) {
	role, err := uc.memberRepo.FindRole(ctx, orgID, userID)
	if err != nil {
		return false, domain.ErrForbidden
	}
	return role == domain.OrgRoleOwner || role == domain.OrgRoleAdmin, nil
}
