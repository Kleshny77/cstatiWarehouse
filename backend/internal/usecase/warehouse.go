package usecase

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/i18n"
)

type WarehouseUseCase struct {
	items       ItemRepository
	members     OrganizationMemberRepository
	events      EventRepository
	activity    ActivityRepository
	broadcaster WebSocketBroadcaster
	clock       Clock
}

func NewWarehouseUseCase(items ItemRepository, members OrganizationMemberRepository, clock Clock) *WarehouseUseCase {
	return &WarehouseUseCase{items: items, members: members, clock: clock}
}

func (uc *WarehouseUseCase) WithActivity(activity ActivityRepository) *WarehouseUseCase {
	uc.activity = activity
	return uc
}

func (uc *WarehouseUseCase) WithEvents(events EventRepository) *WarehouseUseCase {
	uc.events = events
	return uc
}

func (uc *WarehouseUseCase) WithBroadcaster(broadcaster WebSocketBroadcaster) *WarehouseUseCase {
	uc.broadcaster = broadcaster
	return uc
}

func (uc *WarehouseUseCase) logActivity(ctx context.Context, orgID, actorID uuid.UUID, kind domain.ActivityKind, targetType string, targetID *uuid.UUID, summary string) {
	if uc.activity == nil {
		return
	}
	_ = uc.activity.Append(ctx, &domain.ActivityEntry{
		ID:             uuid.New(),
		OrganizationID: orgID,
		ActorUserID:    actorID,
		Kind:           kind,
		TargetType:     targetType,
		TargetID:       targetID,
		Summary:        summary,
		CreatedAt:      uc.clock.Now(),
	})
}

type CreateItemInput struct {
	UserID          uuid.UUID
	OrganizationID  uuid.UUID
	HeldByUserID    *uuid.UUID
	Name            string
	Description     string
	CategoryName    string
	Quantity        int
	ExpirationDate  *time.Time
	ImageURL        *string
	LocationAddress *string
	ParentItemID    *uuid.UUID
	VariantLabel    string
	MeasureUnit     string
	VolumePerUnit   *float64
}

func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	if in.Quantity < 0 {
		return nil, domain.NewValidationError("quantity must be >= 0")
	}
	_, err := uc.requireMember(ctx, in.UserID, in.OrganizationID)
	if err != nil {
		return nil, err
	}

	mu := domain.MeasureUnitPiece
	if strings.TrimSpace(in.MeasureUnit) != "" {
		m, ok := domain.ParseMeasureUnit(strings.TrimSpace(in.MeasureUnit))
		if !ok {
			return nil, domain.NewValidationError("invalid measure_unit")
		}
		mu = m
	}
	if err := validateMeasure(mu); err != nil {
		return nil, err
	}
	if err := domain.ValidateVolumePerUnitPointer(in.VolumePerUnit); err != nil {
		return nil, err
	}

	heldBy := in.UserID
	if in.HeldByUserID != nil {
		heldBy = *in.HeldByUserID
		if _, err := uc.requireMember(ctx, heldBy, in.OrganizationID); err != nil {
			return nil, domain.NewValidationError("held_by user must be a member of the organization")
		}
	}

	var parentItemID *uuid.UUID
	variantLabel := strings.TrimSpace(in.VariantLabel)
	if in.ParentItemID != nil {
		parent, err := uc.items.FindByID(ctx, *in.ParentItemID)
		if err != nil {
			return nil, err
		}
		if parent.OrganizationID != in.OrganizationID {
			return nil, domain.NewValidationError("parent item belongs to a different organization")
		}
		if parent.ParentItemID != nil {
			return nil, domain.NewValidationError("cannot attach variant to another variant")
		}
		if _, err := uc.requireMutableItem(ctx, parent.ID, in.UserID); err != nil {
			return nil, err
		}
		if variantLabel == "" {
			return nil, domain.NewValidationError("variant_label is required for a sub-item")
		}
		parentItemID = in.ParentItemID
	}

	locPtr, err := normalizeRequiredLocationAddress(in.LocationAddress)
	if err != nil {
		return nil, err
	}

	now := uc.clock.Now()
	item := &domain.Item{
		ID:              uuid.New(),
		OrganizationID:  in.OrganizationID,
		HeldByUserID:    heldBy,
		Name:            name,
		Description:     strings.TrimSpace(in.Description),
		CategoryName:    strings.TrimSpace(in.CategoryName),
		Quantity:        in.Quantity,
		Status:          domain.ItemStatusInStock,
		ExpirationDate:  in.ExpirationDate,
		ImageURL:        in.ImageURL,
		LocationAddress: locPtr,
		ParentItemID:    parentItemID,
		VariantLabel:    variantLabel,
		MeasureUnit:     mu,
		VolumePerUnit:   in.VolumePerUnit,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	if err := uc.items.Create(ctx, item); err != nil {
		return nil, err
	}
	uc.logActivity(ctx, item.OrganizationID, in.UserID, domain.ActivityItemCreated, "item", &item.ID, fmt.Sprintf(i18n.ActivityItemCreated, item.Name))
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastItemCreated(item.OrganizationID, item)
	}
	return item, nil
}

type UpdateItemInput struct {
	ID                uuid.UUID
	UserID            uuid.UUID
	HeldByUserID      *uuid.UUID
	Name              string
	Description       string
	CategoryName      string
	Quantity          int
	ExpirationDate    *time.Time
	ImageURL          *string
	LocationAddress   *string
	VariantLabel      string
	MeasureUnit       string
	VolumePerUnit     *float64
	ExpectedUpdatedAt *time.Time
}

func (uc *WarehouseUseCase) Update(ctx context.Context, in UpdateItemInput) (*domain.Item, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	if in.Quantity < 0 {
		return nil, domain.NewValidationError("quantity must be >= 0")
	}
	item, err := uc.requireMutableItem(ctx, in.ID, in.UserID)
	if err != nil {
		return nil, err
	}

	if in.HeldByUserID != nil && *in.HeldByUserID != item.HeldByUserID {
		if _, err := uc.requireMember(ctx, *in.HeldByUserID, item.OrganizationID); err != nil {
			return nil, domain.NewValidationError("held_by user must be a member of the organization")
		}
		item.HeldByUserID = *in.HeldByUserID
	}

	hasChildren, err := uc.items.HasChildRows(ctx, item.ID)
	if err != nil {
		return nil, err
	}
	if hasChildren {
	} else {
		item.Quantity = in.Quantity
	}

	mu := item.MeasureUnit
	if strings.TrimSpace(in.MeasureUnit) != "" {
		m, ok := domain.ParseMeasureUnit(strings.TrimSpace(in.MeasureUnit))
		if !ok {
			return nil, domain.NewValidationError("invalid measure_unit")
		}
		mu = m
	}
	if err := validateMeasure(mu); err != nil {
		return nil, err
	}
	if err := domain.ValidateVolumePerUnitPointer(in.VolumePerUnit); err != nil {
		return nil, err
	}
	item.MeasureUnit = mu
	item.VolumePerUnit = in.VolumePerUnit
	if item.ParentItemID != nil {
		item.VariantLabel = strings.TrimSpace(in.VariantLabel)
		if item.VariantLabel == "" {
			return nil, domain.NewValidationError("variant_label must not be empty")
		}
	}

	locPtr, err := normalizeRequiredLocationAddress(in.LocationAddress)
	if err != nil {
		return nil, err
	}

	item.Name = name
	item.Description = strings.TrimSpace(in.Description)
	item.CategoryName = strings.TrimSpace(in.CategoryName)
	item.ExpirationDate = in.ExpirationDate
	item.ImageURL = in.ImageURL
	item.LocationAddress = locPtr
	item.UpdatedAt = uc.clock.Now()

	if err := uc.items.Update(ctx, item, in.ExpectedUpdatedAt); err != nil {
		return nil, err
	}
	uc.logActivity(ctx, item.OrganizationID, in.UserID, domain.ActivityItemUpdated, "item", &item.ID, fmt.Sprintf(i18n.ActivityItemUpdated, item.Name))
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastItemUpdated(item.OrganizationID, item)
	}
	return item, nil
}

type ArchiveItemInput struct {
	ItemID       uuid.UUID
	UserID       uuid.UUID
	Quantity     int
	Reason       domain.ArchiveReason
	ReasonDetail string
	EventID      *uuid.UUID
}

func (uc *WarehouseUseCase) Archive(ctx context.Context, in ArchiveItemInput) (*domain.Item, *domain.ArchiveEvent, error) {
	if !domain.IsValidArchiveReason(in.Reason) {
		return nil, nil, domain.NewValidationError("invalid archive reason")
	}
	if in.Quantity <= 0 {
		return nil, nil, domain.NewValidationError("quantity must be > 0")
	}
	detail := strings.TrimSpace(in.ReasonDetail)
	if in.Reason == domain.ArchiveReasonUsedAtEvent && detail == "" && in.EventID == nil {
		return nil, nil, domain.NewValidationError("event name or event_id is required for 'usedAtEvent'")
	}
	if in.Reason == domain.ArchiveReasonOther && detail == "" {
		return nil, nil, domain.NewValidationError("reason detail is required for 'other'")
	}
	if in.EventID != nil && in.Reason != domain.ArchiveReasonUsedAtEvent {
		return nil, nil, domain.NewValidationError("event_id is only allowed for 'usedAtEvent'")
	}

	item, err := uc.requireMutableItem(ctx, in.ItemID, in.UserID)
	if err != nil {
		return nil, nil, err
	}
	if item.ParentItemID == nil {
		hasChildren, err := uc.items.HasChildRows(ctx, item.ID)
		if err != nil {
			return nil, nil, err
		}
		if hasChildren {
			return nil, nil, domain.NewValidationError("write off sub-items first; parent row aggregates variants")
		}
	}
	if item.Status == domain.ItemStatusArchived {
		return nil, nil, domain.NewValidationError("item is already archived")
	}
	if in.Quantity > item.Quantity {
		return nil, nil, domain.NewValidationError("quantity exceeds remaining stock")
	}

	if in.EventID != nil {
		if uc.events == nil {
			return nil, nil, domain.NewValidationError("event_id is not supported")
		}
		event, err := uc.events.FindByID(ctx, *in.EventID)
		if err != nil {
			return nil, nil, err
		}
		if event.OrganizationID != item.OrganizationID {
			return nil, nil, domain.NewValidationError("event belongs to a different organization")
		}
		if detail == "" {
			detail = event.Name
		}
	}

	now := uc.clock.Now()
	event := &domain.ArchiveEvent{
		ID:               uuid.New(),
		ItemID:           item.ID,
		OrganizationID:   item.OrganizationID,
		ArchivedByUserID: in.UserID,
		Quantity:         in.Quantity,
		Reason:           in.Reason,
		ReasonDetail:     detail,
		EventID:          in.EventID,
		ArchivedAt:       now,
	}

	item.Quantity -= in.Quantity
	item.UpdatedAt = now
	if item.Quantity == 0 {
		item.Status = domain.ItemStatusArchived
		reasonCopy := in.Reason
		item.ArchiveReason = &reasonCopy
		item.ArchivedAt = &now
	}

	if err := uc.items.RecordArchiveEvent(ctx, item, event); err != nil {
		return nil, nil, err
	}
	uc.logActivity(ctx, item.OrganizationID, in.UserID, domain.ActivityItemArchived, "item", &item.ID, fmt.Sprintf(i18n.ActivityItemArchived, item.Name, string(in.Reason)))
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastItemArchived(item.OrganizationID, item)
	}
	return item, event, nil
}

func (uc *WarehouseUseCase) ListArchiveEvents(ctx context.Context, userID, orgID uuid.UUID, limit, offset int) ([]domain.ArchiveEvent, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.items.ListArchiveEvents(ctx, orgID, limit, offset)
}

func (uc *WarehouseUseCase) Delete(ctx context.Context, id, userID uuid.UUID) error {
	item, err := uc.requireMutableItem(ctx, id, userID)
	if err != nil {
		return err
	}
	orgID := item.OrganizationID
	if err := uc.items.Delete(ctx, id); err != nil {
		return err
	}
	uc.logActivity(ctx, orgID, userID, domain.ActivityItemDeleted, "item", &item.ID, fmt.Sprintf(i18n.ActivityItemDeleted, item.Name))
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastItemDeleted(orgID, id)
	}
	return nil
}

func (uc *WarehouseUseCase) List(ctx context.Context, userID, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.items.ListByOrganization(ctx, orgID, filter)
}

// MARK: private helpers

func validateMeasure(mu domain.MeasureUnit) error {
	switch mu {
	case domain.MeasureUnitPiece, domain.MeasureUnitLiter, domain.MeasureUnitMilliliter,
		domain.MeasureUnitKilogram, domain.MeasureUnitGram:
		return nil
	default:
		return domain.NewValidationError("invalid measure_unit")
	}
}

func normalizeRequiredLocationAddress(p *string) (*string, error) {
	if p == nil {
		return nil, domain.NewValidationError("location_address is required")
	}
	t := strings.TrimSpace(*p)
	if t == "" {
		return nil, domain.NewValidationError("location_address is required")
	}
	return &t, nil
}

func (uc *WarehouseUseCase) requireMember(ctx context.Context, userID, orgID uuid.UUID) (domain.OrgRole, error) {
	role, err := uc.members.FindRole(ctx, orgID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return "", domain.ErrForbidden
		}
		return "", err
	}
	return role, nil
}

func (uc *WarehouseUseCase) requireMutableItem(ctx context.Context, itemID, userID uuid.UUID) (*domain.Item, error) {
	item, err := uc.items.FindByID(ctx, itemID)
	if err != nil {
		return nil, err
	}
	role, err := uc.members.FindRole(ctx, item.OrganizationID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}

	if role.CanManageMembers() {
		return item, nil
	}

	if item.HeldByUserID != userID {
		return nil, domain.ErrForbidden
	}

	return item, nil
}
