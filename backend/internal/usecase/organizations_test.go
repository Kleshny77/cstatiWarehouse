package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func newOrganizationsUC(t *testing.T) (*OrganizationsUseCase, *fakeOrgRepo, *fakeMemberRepo, *fakeClock) {
	t.Helper()
	members := newFakeMemberRepo()
	orgs := newFakeOrgRepo(members)
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))
	return NewOrganizationsUseCase(orgs, members, clock), orgs, members, clock
}

func TestOrganizationsUseCase_Create_MakesOwnerMember(t *testing.T) {
	uc, _, members, _ := newOrganizationsUC(t)
	owner := uuid.New()

	org, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team A"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if org.Name != "Team A" || org.OwnerID != owner || org.IsPersonal {
		t.Errorf("unexpected org: %+v", org)
	}

	role, err := members.FindRole(context.Background(), org.ID, owner)
	if err != nil {
		t.Fatalf("owner must be a member: %v", err)
	}
	if role != domain.OrgRoleOwner {
		t.Errorf("expected owner role, got %s", role)
	}
}

func TestOrganizationsUseCase_Create_EmptyName(t *testing.T) {
	uc, _, _, _ := newOrganizationsUC(t)
	if _, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: uuid.New(), Name: "   "}); !errors.Is(err, domain.ErrValidation) {
		t.Errorf("expected ErrValidation, got %v", err)
	}
}

func TestOrganizationsUseCase_CreatePersonal_IsPersonal(t *testing.T) {
	uc, _, _, _ := newOrganizationsUC(t)
	owner := uuid.New()

	org, err := uc.CreatePersonal(context.Background(), owner, "Артём")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !org.IsPersonal {
		t.Error("personal org must have IsPersonal=true")
	}
	if org.Name != "Склад Артём" {
		t.Errorf("unexpected name: %q", org.Name)
	}
}

func TestOrganizationsUseCase_ListMine(t *testing.T) {
	uc, _, _, clock := newOrganizationsUC(t)
	owner := uuid.New()

	if _, err := uc.CreatePersonal(context.Background(), owner, "A"); err != nil {
		t.Fatalf("personal failed: %v", err)
	}
	clock.Advance(time.Second)
	if _, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Work"}); err != nil {
		t.Fatalf("create failed: %v", err)
	}

	list, err := uc.ListMine(context.Background(), owner)
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if len(list) != 2 {
		t.Fatalf("expected 2 orgs, got %d", len(list))
	}
	if !list[0].Organization.IsPersonal {
		t.Error("personal org must come first")
	}
}

func TestOrganizationsUseCase_Update_RequiresOwnerOrAdmin(t *testing.T) {
	uc, _, members, _ := newOrganizationsUC(t)
	owner := uuid.New()
	member := uuid.New()

	org, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Old"})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: org.ID, UserID: member, Role: domain.OrgRoleMember, JoinedAt: time.Now(),
	}); err != nil {
		t.Fatalf("seed member failed: %v", err)
	}

	name := "New"
	if _, err := uc.Update(context.Background(), UpdateOrganizationInput{UserID: member, OrgID: org.ID, Name: &name}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member must not be allowed to edit, got %v", err)
	}

	updated, err := uc.Update(context.Background(), UpdateOrganizationInput{UserID: owner, OrgID: org.ID, Name: &name})
	if err != nil {
		t.Fatalf("owner update failed: %v", err)
	}
	if updated.Name != "New" {
		t.Errorf("name not updated: %+v", updated)
	}
}

func TestOrganizationsUseCase_Leave_OwnerForbidden(t *testing.T) {
	uc, _, members, _ := newOrganizationsUC(t)
	owner := uuid.New()
	member := uuid.New()

	org, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	if err := members.Add(context.Background(), &domain.OrganizationMember{
		OrganizationID: org.ID, UserID: member, Role: domain.OrgRoleMember, JoinedAt: time.Now(),
	}); err != nil {
		t.Fatalf("seed member failed: %v", err)
	}

	if err := uc.Leave(context.Background(), owner, org.ID); !errors.Is(err, domain.ErrOwnerCannotLeave) {
		t.Errorf("owner must not be able to leave, got %v", err)
	}
	if err := uc.Leave(context.Background(), member, org.ID); err != nil {
		t.Errorf("member leave failed: %v", err)
	}
}

func TestOrganizationsUseCase_Delete_PersonalProtected(t *testing.T) {
	uc, _, _, _ := newOrganizationsUC(t)
	owner := uuid.New()

	personal, err := uc.CreatePersonal(context.Background(), owner, "Me")
	if err != nil {
		t.Fatalf("create personal failed: %v", err)
	}
	if err := uc.Delete(context.Background(), owner, personal.ID); !errors.Is(err, domain.ErrCannotDeletePersonalOrg) {
		t.Errorf("expected ErrCannotDeletePersonalOrg, got %v", err)
	}
}
