package domain

import (
	"time"

	"github.com/google/uuid"
)

type ItemStatus string

const (
	ItemStatusInStock  ItemStatus = "in_stock"
	ItemStatusArchived ItemStatus = "archived"
)

type ArchiveReason string

const (
	ArchiveReasonUsedAtEvent ArchiveReason = "usedAtEvent"
	ArchiveReasonExpired     ArchiveReason = "expired"
	ArchiveReasonDisposed    ArchiveReason = "disposed"
	ArchiveReasonLost        ArchiveReason = "lost"
	ArchiveReasonOther       ArchiveReason = "other"
)

func IsValidArchiveReason(r ArchiveReason) bool {
	switch r {
	case ArchiveReasonUsedAtEvent, ArchiveReasonExpired, ArchiveReasonDisposed,
		ArchiveReasonLost, ArchiveReasonOther:
		return true
	}
	return false
}

type Item struct {
	ID             uuid.UUID
	OwnerID        uuid.UUID
	Name           string
	Description    string
	CategoryName   string
	Quantity       int
	Status         ItemStatus
	ArchiveReason  *ArchiveReason
	ArchivedAt     *time.Time
	ExpirationDate *time.Time
	ImageURL       *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

func (i *Item) IsOwnedBy(userID uuid.UUID) bool {
	return i.OwnerID == userID
}
