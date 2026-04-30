package domain

import (
	"time"

	"github.com/google/uuid"
)

type ReservationStatus string

const (
	ReservationStatusActive    ReservationStatus = "active"
	ReservationStatusFulfilled ReservationStatus = "fulfilled"
	ReservationStatusCancelled ReservationStatus = "cancelled"
	ReservationStatusExpired   ReservationStatus = "expired"
)

func (s ReservationStatus) IsValid() bool {
	switch s {
	case ReservationStatusActive, ReservationStatusFulfilled, ReservationStatusCancelled, ReservationStatusExpired:
		return true
	}
	return false
}

// ItemReservation — бронь количества товара под мероприятие (event).
// Назначение: исключить гонку между двумя мероприятиями, одновременно
// претендующими на одну и ту же позицию склада.
type ItemReservation struct {
	ID             uuid.UUID
	ItemID         uuid.UUID
	OrganizationID uuid.UUID

	Quantity int
	EventID  *uuid.UUID // под какое событие зарезервировано (опционально)

	ReservedByUserID uuid.UUID
	ReservedAt       time.Time
	ExpiresAt        *time.Time // NULL = бессрочно

	Status ReservationStatus

	FulfilledAt       *time.Time
	FulfilledByUserID *uuid.UUID

	CancelledAt        *time.Time
	CancelledByUserID  *uuid.UUID
	CancellationReason string

	Notes     string // свободный комментарий: «забрали в N раз / нужно вернуть к ...»
	CreatedAt time.Time
	UpdatedAt time.Time
}

func (r *ItemReservation) IsActive() bool {
	return r.Status == ReservationStatusActive
}

func (r *ItemReservation) IsExpired(now time.Time) bool {
	return r.ExpiresAt != nil && !r.ExpiresAt.After(now)
}

func (r *ItemReservation) CanBeCancelledBy(userID uuid.UUID, isAdmin bool) bool {
	if r.Status != ReservationStatusActive {
		return false
	}
	return r.ReservedByUserID == userID || isAdmin
}

func (r *ItemReservation) CanBeFulfilledBy(userID uuid.UUID, isAdmin bool) bool {
	if r.Status != ReservationStatusActive {
		return false
	}
	return r.ReservedByUserID == userID || isAdmin
}
