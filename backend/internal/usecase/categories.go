//
// categories.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package usecase

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/i18n"
)

type CategoriesUseCase struct {
	categories CategoryRepository
	members    OrganizationMemberRepository
	activity   ActivityRepository
	clock      Clock
}

func NewCategoriesUseCase(
	categories CategoryRepository,
	members OrganizationMemberRepository,
	activity ActivityRepository,
	clock Clock,
) *CategoriesUseCase {
	return &CategoriesUseCase{categories: categories, members: members, activity: activity, clock: clock}
}

func (uc *CategoriesUseCase) List(ctx context.Context, userID, orgID uuid.UUID) ([]domain.Category, error) {
	if err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.categories.ListByOrganization(ctx, orgID)
}

type CreateCategoryInput struct {
	UserID         uuid.UUID
	OrganizationID uuid.UUID
	Name           string
}

func (uc *CategoriesUseCase) Create(ctx context.Context, in CreateCategoryInput) (*domain.Category, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("category name must not be empty")
	}
	if err := uc.requireManager(ctx, in.UserID, in.OrganizationID); err != nil {
		return nil, err
	}

	c := &domain.Category{
		ID:             uuid.New(),
		OrganizationID: in.OrganizationID,
		CreatedByID:    in.UserID,
		Name:           name,
		CreatedAt:      uc.clock.Now(),
	}
	if err := uc.categories.Create(ctx, c); err != nil {
		return nil, err
	}
	uc.logActivity(ctx, in.OrganizationID, in.UserID, domain.ActivityCategoryCreated, "category", &c.ID, fmt.Sprintf(i18n.ActivityCategoryCreated, c.Name))
	return c, nil
}

func (uc *CategoriesUseCase) Delete(ctx context.Context, userID, categoryID uuid.UUID) error {
	c, err := uc.categories.FindByID(ctx, categoryID)
	if err != nil {
		return err
	}
	if err := uc.requireManager(ctx, userID, c.OrganizationID); err != nil {
		return err
	}
	if err := uc.categories.Delete(ctx, categoryID); err != nil {
		return err
	}
	uc.logActivity(ctx, c.OrganizationID, userID, domain.ActivityCategoryDeleted, "category", &c.ID, fmt.Sprintf(i18n.ActivityCategoryDeleted, c.Name))
	return nil
}

func (uc *CategoriesUseCase) requireMember(ctx context.Context, userID, orgID uuid.UUID) error {
	if _, err := uc.members.FindRole(ctx, orgID, userID); err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return domain.ErrForbidden
		}
		return err
	}
	return nil
}

func (uc *CategoriesUseCase) requireManager(ctx context.Context, userID, orgID uuid.UUID) error {
	role, err := uc.members.FindRole(ctx, orgID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return domain.ErrForbidden
		}
		return err
	}
	if role != domain.OrgRoleOwner && role != domain.OrgRoleAdmin {
		return domain.ErrForbidden
	}
	return nil
}

func (uc *CategoriesUseCase) logActivity(ctx context.Context, orgID, userID uuid.UUID, kind domain.ActivityKind, targetType string, targetID *uuid.UUID, summary string) {
	if uc.activity == nil {
		return
	}
	_ = uc.activity.Append(ctx, &domain.ActivityEntry{
		ID:             uuid.New(),
		OrganizationID: orgID,
		ActorUserID:    userID,
		Kind:           kind,
		TargetType:     targetType,
		TargetID:       targetID,
		Summary:        summary,
		CreatedAt:      uc.clock.Now(),
	})
}
