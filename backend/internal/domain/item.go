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

type MeasureUnit string

const (
	MeasureUnitPiece      MeasureUnit = "piece"
	MeasureUnitLiter      MeasureUnit = "liter"
	MeasureUnitMilliliter MeasureUnit = "milliliter"
	MeasureUnitKilogram   MeasureUnit = "kilogram"
	MeasureUnitGram       MeasureUnit = "gram"
)

func ParseMeasureUnit(s string) (MeasureUnit, bool) {
	switch MeasureUnit(s) {
	case MeasureUnitPiece, MeasureUnitLiter, MeasureUnitMilliliter, MeasureUnitKilogram, MeasureUnitGram:
		return MeasureUnit(s), true
	default:
		return "", false
	}
}

// EffectiveAmountPerUnit возвращает размер одной упаковки в выбранной мере.
// nil или неположительное значение трактуются как 1 (одна единица меры на упаковку).
func EffectiveAmountPerUnit(v *float64) float64 {
	if v == nil {
		return 1
	}
	if *v <= 0 {
		return 1
	}
	return *v
}

// ValidateVolumePerUnitPointer проверяет явно переданное значение volume_per_unit.
func ValidateVolumePerUnitPointer(v *float64) error {
	if v == nil {
		return nil
	}
	if *v <= 0 {
		return NewValidationError("volume_per_unit must be > 0")
	}
	return nil
}

type Item struct {
	ID              uuid.UUID
	OrganizationID  uuid.UUID
	HeldByUserID    uuid.UUID
	Name            string
	Description     string
	CategoryName    string
	Quantity        int
	Status          ItemStatus
	ArchiveReason   *ArchiveReason
	ArchivedAt      *time.Time
	ExpirationDate  *time.Time
	ImageURL        *string
	LocationAddress *string
	ParentItemID    *uuid.UUID
	VariantLabel    string
	MeasureUnit     MeasureUnit
	VolumePerUnit   *float64
	DeletedAt       *time.Time
	DeletedByUserID *uuid.UUID
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// ItemVersionConflictError возвращается, если `expected_updated_at` не совпал с текущим
// значением в БД (другой клиент или устройство успели изменить позицию).
type ItemVersionConflictError struct {
	ServerItem Item
}

func (e *ItemVersionConflictError) Error() string {
	return "item version conflict"
}

func (i *Item) IsHeldBy(userID uuid.UUID) bool {
	return i.HeldByUserID == userID
}

func (i *Item) BelongsToOrganization(orgID uuid.UUID) bool {
	return i.OrganizationID == orgID
}

func (i *Item) IsDeleted() bool {
	return i.DeletedAt != nil
}

func (i *Item) IsActive() bool {
	return i.DeletedAt == nil
}
