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

// MeasureUnit — единица учёта остатка по строке склада.
type MeasureUnit string

const (
	MeasureUnitPiece    MeasureUnit = "piece"    // штуки
	MeasureUnitPackage  MeasureUnit = "package"  // упаковки
	MeasureUnitMeter    MeasureUnit = "meter"    // метры
	MeasureUnitLiter    MeasureUnit = "liter"    // объём: quantity × volume_per_unit = литры
)

func ParseMeasureUnit(s string) (MeasureUnit, bool) {
	switch MeasureUnit(s) {
	case MeasureUnitPiece, MeasureUnitPackage, MeasureUnitMeter, MeasureUnitLiter:
		return MeasureUnit(s), true
	default:
		return "", false
	}
}

type Item struct {
	ID               uuid.UUID
	OrganizationID   uuid.UUID
	HeldByUserID     uuid.UUID
	Name             string
	Description      string
	CategoryName     string
	Quantity        int
	Status          ItemStatus
	ArchiveReason    *ArchiveReason
	ArchivedAt       *time.Time
	ExpirationDate   *time.Time
	ImageURL         *string
	LocationAddress  *string
	ParentItemID     *uuid.UUID
	VariantLabel     string
	MeasureUnit      MeasureUnit
	VolumePerUnit    *float64
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// IsHeldBy возвращает true, если айтем физически находится у указанного пользователя.
func (i *Item) IsHeldBy(userID uuid.UUID) bool {
	return i.HeldByUserID == userID
}

// BelongsToOrganization проверяет, что айтем принадлежит указанной организации.
func (i *Item) BelongsToOrganization(orgID uuid.UUID) bool {
	return i.OrganizationID == orgID
}
