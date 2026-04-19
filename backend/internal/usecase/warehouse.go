package usecase

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type WarehouseUseCase struct {
	items ItemRepository
	clock Clock
}

func NewWarehouseUseCase(items ItemRepository, clock Clock) *WarehouseUseCase {
	return &WarehouseUseCase{items: items, clock: clock}
}

type CreateItemInput struct {
	OwnerID        uuid.UUID
	Name           string
	Description    string
	CategoryName   string
	Quantity       int
	ExpirationDate *time.Time
	ImageURL       *string
}

func (uc *WarehouseUseCase) Create(ctx context.Context, in CreateItemInput) (*domain.Item, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	if in.Quantity < 0 {
		return nil, domain.NewValidationError("quantity must be >= 0")
	}

	now := uc.clock.Now()
	item := &domain.Item{
		ID:             uuid.New(),
		OwnerID:        in.OwnerID,
		Name:           name,
		Description:    strings.TrimSpace(in.Description),
		CategoryName:   strings.TrimSpace(in.CategoryName),
		Quantity:       in.Quantity,
		Status:         domain.ItemStatusInStock,
		ExpirationDate: in.ExpirationDate,
		ImageURL:       in.ImageURL,
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	if err := uc.items.Create(ctx, item); err != nil {
		return nil, err
	}
	return item, nil
}

type UpdateItemInput struct {
	ID             uuid.UUID
	OwnerID        uuid.UUID
	Name           string
	Description    string
	CategoryName   string
	Quantity       int
	ExpirationDate *time.Time
	ImageURL       *string
}

func (uc *WarehouseUseCase) Update(ctx context.Context, in UpdateItemInput) (*domain.Item, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	if in.Quantity < 0 {
		return nil, domain.NewValidationError("quantity must be >= 0")
	}

	item, err := uc.requireOwnedItem(ctx, in.ID, in.OwnerID)
	if err != nil {
		return nil, err
	}

	item.Name = name
	item.Description = strings.TrimSpace(in.Description)
	item.CategoryName = strings.TrimSpace(in.CategoryName)
	item.Quantity = in.Quantity
	item.ExpirationDate = in.ExpirationDate
	item.ImageURL = in.ImageURL
	item.UpdatedAt = uc.clock.Now()

	if err := uc.items.Update(ctx, item); err != nil {
		return nil, err
	}
	return item, nil
}

// ArchiveItemInput описывает одно событие списания со стака.
// Quantity < item.Quantity → частичное списание (остаток уменьшается).
// Quantity == item.Quantity → позиция полностью уходит в архив.
type ArchiveItemInput struct {
	ItemID       uuid.UUID
	OwnerID      uuid.UUID
	Quantity     int
	Reason       domain.ArchiveReason
	ReasonDetail string
}

// Archive проводит списание quantity единиц из стака, фиксирует событие в истории.
// Возвращает обновлённую позицию и созданное событие.
func (uc *WarehouseUseCase) Archive(ctx context.Context, in ArchiveItemInput) (*domain.Item, *domain.ArchiveEvent, error) {
	if !domain.IsValidArchiveReason(in.Reason) {
		return nil, nil, domain.NewValidationError("invalid archive reason")
	}
	if in.Quantity <= 0 {
		return nil, nil, domain.NewValidationError("quantity must be > 0")
	}
	detail := strings.TrimSpace(in.ReasonDetail)
	if in.Reason == domain.ArchiveReasonUsedAtEvent && detail == "" {
		return nil, nil, domain.NewValidationError("event name is required for 'usedAtEvent'")
	}
	if in.Reason == domain.ArchiveReasonOther && detail == "" {
		return nil, nil, domain.NewValidationError("reason detail is required for 'other'")
	}

	item, err := uc.requireOwnedItem(ctx, in.ItemID, in.OwnerID)
	if err != nil {
		return nil, nil, err
	}
	if item.Status == domain.ItemStatusArchived {
		return nil, nil, domain.NewValidationError("item is already archived")
	}
	if in.Quantity > item.Quantity {
		return nil, nil, domain.NewValidationError("quantity exceeds remaining stock")
	}

	now := uc.clock.Now()
	event := &domain.ArchiveEvent{
		ID:           uuid.New(),
		ItemID:       item.ID,
		OwnerID:      item.OwnerID,
		Quantity:     in.Quantity,
		Reason:       in.Reason,
		ReasonDetail: detail,
		ArchivedAt:   now,
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
	return item, event, nil
}

func (uc *WarehouseUseCase) ListArchiveEvents(ctx context.Context, ownerID uuid.UUID) ([]domain.ArchiveEvent, error) {
	return uc.items.ListArchiveEvents(ctx, ownerID)
}

func (uc *WarehouseUseCase) Delete(ctx context.Context, id, ownerID uuid.UUID) error {
	if _, err := uc.requireOwnedItem(ctx, id, ownerID); err != nil {
		return err
	}
	return uc.items.Delete(ctx, id)
}

func (uc *WarehouseUseCase) List(ctx context.Context, ownerID uuid.UUID, filter ItemFilter) ([]domain.Item, error) {
	return uc.items.ListByOwner(ctx, ownerID, filter)
}

func (uc *WarehouseUseCase) Categories(ctx context.Context, ownerID uuid.UUID) ([]string, error) {
	return uc.items.ListCategoriesByOwner(ctx, ownerID)
}

// MARK: private helpers

func (uc *WarehouseUseCase) requireOwnedItem(ctx context.Context, id, ownerID uuid.UUID) (*domain.Item, error) {
	item, err := uc.items.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if !item.IsOwnedBy(ownerID) {
		// Возвращаем NotFound, чтобы не леакать существование чужих записей.
		return nil, domain.ErrNotFound
	}
	return item, nil
}
