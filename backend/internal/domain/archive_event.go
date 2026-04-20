package domain

import (
	"time"

	"github.com/google/uuid"
)

// ArchiveEvent — единичное списание со стака (quantity ≥ 1).
// Из одной позиции может быть много событий: разные мероприятия, части партии и т.д.
type ArchiveEvent struct {
	ID               uuid.UUID
	ItemID           uuid.UUID
	OrganizationID   uuid.UUID
	ArchivedByUserID uuid.UUID
	Quantity         int
	Reason           ArchiveReason
	ReasonDetail     string
	// EventID — опциональная связь с мероприятием организации.
	// Заполняется, когда Reason == usedAtEvent и пользователь выбрал конкретное event,
	// а не вписал название текстом.
	EventID    *uuid.UUID
	ArchivedAt time.Time

	// Заполняются только в ListArchiveEvents (JOIN с items / users), не при Insert.
	ItemName              string
	ArchivedByDisplayName string
}
