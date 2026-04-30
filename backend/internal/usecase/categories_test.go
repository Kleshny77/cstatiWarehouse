//
// categories_test.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func newCategoriesUC(t *testing.T) (*CategoriesUseCase, *fakeMemberRepo, uuid.UUID, uuid.UUID) {
	t.Helper()
	members := newFakeMemberRepo()
	orgID := uuid.New()
	ownerID := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         ownerID,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("add owner: %v", err)
	}
	cats := newFakeCategoryRepo()
	activity := newFakeActivityRepo()
	clock := newFakeClock(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))
	uc := NewCategoriesUseCase(cats, members, activity, clock)
	return uc, members, ownerID, orgID
}

func TestCategoriesUseCase_CreateAndList(t *testing.T) {
	uc, members, ownerID, orgID := newCategoriesUC(t)
	c, err := uc.Create(context.Background(), CreateCategoryInput{
		UserID:         ownerID,
		OrganizationID: orgID,
		Name:           "  напитки  ",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if c.Name != "напитки" {
		t.Fatalf("name not trimmed: %q", c.Name)
	}

	member := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         member,
		Role:           domain.OrgRoleMember,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("add member: %v", err)
	}
	list, err := uc.List(context.Background(), member, orgID)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1 category, got %d", len(list))
	}
}

func TestCategoriesUseCase_DeleteRequiresManager(t *testing.T) {
	uc, members, ownerID, orgID := newCategoriesUC(t)
	c, err := uc.Create(context.Background(), CreateCategoryInput{
		UserID:         ownerID,
		OrganizationID: orgID,
		Name:           "x",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	member := uuid.New()
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: orgID,
		UserID:         member,
		Role:           domain.OrgRoleMember,
		JoinedAt:       time.Now(),
	}); err != nil {
		t.Fatalf("add member: %v", err)
	}
	if err := uc.Delete(context.Background(), member, c.ID); !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("expected forbidden, got %v", err)
	}
	if err := uc.Delete(context.Background(), ownerID, c.ID); err != nil {
		t.Fatalf("owner delete: %v", err)
	}
}
