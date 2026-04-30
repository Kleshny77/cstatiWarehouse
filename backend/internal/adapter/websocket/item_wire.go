package websocket

import (
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type wsItemDTO struct {
	ID                     string      `json:"id"`
	OrganizationID         string      `json:"organization_id"`
	HeldByUserID           string      `json:"held_by_user_id"`
	Name                   string      `json:"name"`
	Description            string      `json:"description"`
	CategoryName           string      `json:"category_name"`
	Quantity               int         `json:"quantity"`
	Status                 string      `json:"status"`
	ArchiveReason          *string     `json:"archive_reason,omitempty"`
	ArchivedAt             *time.Time  `json:"archived_at,omitempty"`
	ExpirationDate         *time.Time  `json:"expiration_date,omitempty"`
	ImageURL               *string     `json:"image_url,omitempty"`
	LocationAddress        *string     `json:"location_address,omitempty"`
	ParentItemID           *string     `json:"parent_item_id,omitempty"`
	VariantLabel           string      `json:"variant_label,omitempty"`
	MeasureUnit            string      `json:"measure_unit"`
	VolumePerUnit          *float64    `json:"volume_per_unit,omitempty"`
	Variants               []wsItemDTO `json:"variants,omitempty"`
	AggregatedVolumeLiters *float64    `json:"aggregated_volume_liters,omitempty"`
	CreatedAt              time.Time   `json:"created_at"`
	UpdatedAt              time.Time   `json:"updated_at"`
}

func uuidPtrToWire(id *uuid.UUID) *string {
	if id == nil {
		return nil
	}
	s := id.String()
	return &s
}

func domainItemToWire(i *domain.Item) wsItemDTO {
	if i == nil {
		return wsItemDTO{}
	}
	mu := i.MeasureUnit
	if mu == "" {
		mu = domain.MeasureUnitPiece
	}
	dto := wsItemDTO{
		ID:              i.ID.String(),
		OrganizationID:  i.OrganizationID.String(),
		HeldByUserID:    i.HeldByUserID.String(),
		Name:            i.Name,
		Description:     i.Description,
		CategoryName:    i.CategoryName,
		Quantity:        i.Quantity,
		Status:          string(i.Status),
		ArchivedAt:      i.ArchivedAt,
		ExpirationDate:  i.ExpirationDate,
		ImageURL:        i.ImageURL,
		LocationAddress: i.LocationAddress,
		ParentItemID:    uuidPtrToWire(i.ParentItemID),
		VariantLabel:    i.VariantLabel,
		MeasureUnit:     string(mu),
		VolumePerUnit:   i.VolumePerUnit,
		CreatedAt:       i.CreatedAt,
		UpdatedAt:       i.UpdatedAt,
	}
	if i.ArchiveReason != nil {
		s := string(*i.ArchiveReason)
		dto.ArchiveReason = &s
	}
	return dto
}
