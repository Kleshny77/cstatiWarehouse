package usecase

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// WarehouseUseCase — бизнес-логика работы со складом в рамках одной организации.
// Авторизация проверяется через членство пользователя в организации айтема.
type WarehouseUseCase struct {
	items   ItemRepository
	members OrganizationMemberRepository
	clock   Clock
}

func NewWarehouseUseCase(items ItemRepository, members OrganizationMemberRepository, clock Clock) *WarehouseUseCase {
	return &WarehouseUseCase{items: items, members: members, clock: clock}
}

type CreateItemInput struct {
	UserID         uuid.UUID
	OrganizationID uuid.UUID
	// HeldByUserID — опциональный держатель. Если nil, держателем становится UserID.
	HeldByUserID   *uuid.UUID
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
	if _, err := uc.requireMember(ctx, in.UserID, in.OrganizationID); err != nil {
		return nil, err
	}

	heldBy := in.UserID
	if in.HeldByUserID != nil {
		heldBy = *in.HeldByUserID
		if _, err := uc.requireMember(ctx, heldBy, in.OrganizationID); err != nil {
			// Держатель обязан быть членом той же организации.
			return nil, domain.NewValidationError("held_by user must be a member of the organization")
		}
	}

	now := uc.clock.Now()
	item := &domain.Item{
		ID:             uuid.New(),
		OrganizationID: in.OrganizationID,
		HeldByUserID:   heldBy,
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
	UserID         uuid.UUID
	HeldByUserID   *uuid.UUID
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

	item, err := uc.requireAccessibleItem(ctx, in.ID, in.UserID)
	if err != nil {
		return nil, err
	}

	if in.HeldByUserID != nil && *in.HeldByUserID != item.HeldByUserID {
		if _, err := uc.requireMember(ctx, *in.HeldByUserID, item.OrganizationID); err != nil {
			return nil, domain.NewValidationError("held_by user must be a member of the organization")
		}
		item.HeldByUserID = *in.HeldByUserID
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
	UserID       uuid.UUID
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

	item, err := uc.requireAccessibleItem(ctx, in.ItemID, in.UserID)
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
		ID:               uuid.New(),
		ItemID:           item.ID,
		OrganizationID:   item.OrganizationID,
		ArchivedByUserID: in.UserID,
		Quantity:         in.Quantity,
		Reason:           in.Reason,
		ReasonDetail:     detail,
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
	return item, event, nil
}

func (uc *WarehouseUseCase) ListArchiveEvents(ctx context.Context, userID, orgID uuid.UUID) ([]domain.ArchiveEvent, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.items.ListArchiveEvents(ctx, orgID)
}

func (uc *WarehouseUseCase) Delete(ctx context.Context, id, userID uuid.UUID) error {
	if _, err := uc.requireAccessibleItem(ctx, id, userID); err != nil {
		return err
	}
	return uc.items.Delete(ctx, id)
}

func (uc *WarehouseUseCase) List(ctx context.Context, userID, orgID uuid.UUID, filter ItemFilter) ([]domain.Item, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.items.ListByOrganization(ctx, orgID, filter)
}

func (uc *WarehouseUseCase) Categories(ctx context.Context, userID, orgID uuid.UUID) ([]string, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.items.ListCategoriesByOrganization(ctx, orgID)
}

// MARK: private helpers

// requireMember возвращает роль пользователя в организации или ErrForbidden, если тот не участник.
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

// requireAccessibleItem загружает айтем и проверяет, что пользователь — участник его организации.
// Если айтема нет или пользователь не в организации — возвращаем ErrNotFound,
// чтобы не раскрывать существование чужих записей.
func (uc *WarehouseUseCase) requireAccessibleItem(ctx context.Context, itemID, userID uuid.UUID) (*domain.Item, error) {
	item, err := uc.items.FindByID(ctx, itemID)
	if err != nil {
		return nil, err
	}
	if _, err := uc.members.FindRole(ctx, item.OrganizationID, userID); err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return item, nil
}
