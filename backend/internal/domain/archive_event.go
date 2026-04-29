package domain

import (
	"time"

	"github.com/google/uuid"
)

type ArchiveEvent struct {
	ID               uuid.UUID
	ItemID           uuid.UUID
	OrganizationID   uuid.UUID
	ArchivedByUserID uuid.UUID
	Quantity         int
	Reason           ArchiveReason
	ReasonDetail     string
	EventID          *uuid.UUID
	ArchivedAt       time.Time

	ItemName              string
	ArchivedByDisplayName string
}
