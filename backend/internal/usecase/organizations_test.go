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
	invites := newFakeInviteRepo()
	gen := newFakeInviteGen()
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))
	return NewOrganizationsUseCase(orgs, members, invites, gen, clock), orgs, members, clock
}

func newOrganizationsUCWithInvites(t *testing.T) (*OrganizationsUseCase, *fakeOrgRepo, *fakeMemberRepo, *fakeInviteRepo, *fakeClock) {
	t.Helper()
	members := newFakeMemberRepo()
	orgs := newFakeOrgRepo(members)
	invites := newFakeInviteRepo()
	gen := newFakeInviteGen()
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))
	return NewOrganizationsUseCase(orgs, members, invites, gen, clock), orgs, members, invites, clock
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

func TestOrganizationsUseCase_CreateInvite_RequiresManager(t *testing.T) {
	uc, _, members, _, _ := newOrganizationsUCWithInvites(t)
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

	if _, err := uc.CreateInvite(context.Background(), CreateInviteInput{ActorID: member, OrgID: org.ID}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("member must not create invites, got %v", err)
	}
	invite, err := uc.CreateInvite(context.Background(), CreateInviteInput{ActorID: owner, OrgID: org.ID})
	if err != nil {
		t.Fatalf("owner create invite failed: %v", err)
	}
	if invite.Code == "" || invite.OrganizationID != org.ID {
		t.Errorf("unexpected invite: %+v", invite)
	}
}

func TestOrganizationsUseCase_JoinByCode_HappyPath(t *testing.T) {
	uc, _, members, _, _ := newOrganizationsUCWithInvites(t)
	owner := uuid.New()
	joiner := uuid.New()

	org, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	invite, err := uc.CreateInvite(context.Background(), CreateInviteInput{ActorID: owner, OrgID: org.ID})
	if err != nil {
		t.Fatalf("invite failed: %v", err)
	}

	got, role, err := uc.JoinByCode(context.Background(), joiner, invite.Code)
	if err != nil {
		t.Fatalf("join failed: %v", err)
	}
	if got.ID != org.ID || role != domain.OrgRoleMember {
		t.Errorf("unexpected: %+v role=%s", got, role)
	}
	if r, err := members.FindRole(context.Background(), org.ID, joiner); err != nil || r != domain.OrgRoleMember {
		t.Errorf("joiner must be member, got %s, err=%v", r, err)
	}
}

func TestOrganizationsUseCase_JoinByCode_Revoked(t *testing.T) {
	uc, _, _, _, _ := newOrganizationsUCWithInvites(t)
	owner := uuid.New()
	joiner := uuid.New()

	org, err := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	invite, err := uc.CreateInvite(context.Background(), CreateInviteInput{ActorID: owner, OrgID: org.ID})
	if err != nil {
		t.Fatalf("invite failed: %v", err)
	}
	if err := uc.RevokeInvite(context.Background(), owner, org.ID, invite.ID); err != nil {
		t.Fatalf("revoke failed: %v", err)
	}

	if _, _, err := uc.JoinByCode(context.Background(), joiner, invite.Code); !errors.Is(err, domain.ErrInviteNotUsable) {
		t.Errorf("expected ErrInviteNotUsable, got %v", err)
	}
}

func TestOrganizationsUseCase_RemoveMember_CannotTargetOwner(t *testing.T) {
	uc, _, members, _ := newOrganizationsUC(t)
	owner := uuid.New()
	admin := uuid.New()

	org, _ := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	_ = members.Add(context.Background(), &domain.OrganizationMember{OrganizationID: org.ID, UserID: admin, Role: domain.OrgRoleAdmin, JoinedAt: time.Now()})

	if err := uc.RemoveMember(context.Background(), admin, org.ID, owner); !errors.Is(err, domain.ErrCannotTargetOwner) {
		t.Errorf("expected ErrCannotTargetOwner, got %v", err)
	}
}

func TestOrganizationsUseCase_ChangeRole_OwnerAndAdmin(t *testing.T) {
	uc, _, members, _ := newOrganizationsUC(t)
	owner := uuid.New()
	admin := uuid.New()
	member := uuid.New()
	peerAdmin := uuid.New()

	org, _ := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	_ = members.Add(context.Background(), &domain.OrganizationMember{OrganizationID: org.ID, UserID: admin, Role: domain.OrgRoleAdmin, JoinedAt: time.Now()})
	_ = members.Add(context.Background(), &domain.OrganizationMember{OrganizationID: org.ID, UserID: peerAdmin, Role: domain.OrgRoleAdmin, JoinedAt: time.Now()})
	_ = members.Add(context.Background(), &domain.OrganizationMember{OrganizationID: org.ID, UserID: member, Role: domain.OrgRoleMember, JoinedAt: time.Now()})

	if err := uc.ChangeRole(context.Background(), ChangeRoleInput{ActorID: admin, OrgID: org.ID, TargetID: peerAdmin, NewRole: domain.OrgRoleMember}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("admin must not demote another admin, got %v", err)
	}

	if err := uc.ChangeRole(context.Background(), ChangeRoleInput{ActorID: admin, OrgID: org.ID, TargetID: member, NewRole: domain.OrgRoleAdmin}); err != nil {
		t.Fatalf("admin promote member to admin: %v", err)
	}
	if r, _ := members.FindRole(context.Background(), org.ID, member); r != domain.OrgRoleAdmin {
		t.Fatalf("expected member promoted to admin, got %s", r)
	}

	if err := uc.ChangeRole(context.Background(), ChangeRoleInput{ActorID: admin, OrgID: org.ID, TargetID: member, NewRole: domain.OrgRoleMember}); !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("admin must not demote (including promoted peers), got %v", err)
	}

	if err := uc.ChangeRole(context.Background(), ChangeRoleInput{ActorID: owner, OrgID: org.ID, TargetID: member, NewRole: domain.OrgRoleMember}); err != nil {
		t.Fatalf("owner demote admin to member: %v", err)
	}
	if r, _ := members.FindRole(context.Background(), org.ID, member); r != domain.OrgRoleMember {
		t.Errorf("expected member demoted by owner, got %s", r)
	}

	if err := uc.ChangeRole(context.Background(), ChangeRoleInput{ActorID: owner, OrgID: org.ID, TargetID: member, NewRole: domain.OrgRoleAdmin}); err != nil {
		t.Fatalf("owner promote member: %v", err)
	}
	if r, _ := members.FindRole(context.Background(), org.ID, member); r != domain.OrgRoleAdmin {
		t.Errorf("role not updated: %s", r)
	}
}

func TestOrganizationsUseCase_TransferOwnership(t *testing.T) {
	uc, orgs, members, _ := newOrganizationsUC(t)
	owner := uuid.New()
	target := uuid.New()

	org, _ := uc.Create(context.Background(), CreateOrganizationInput{OwnerID: owner, Name: "Team"})
	_ = members.Add(context.Background(), &domain.OrganizationMember{OrganizationID: org.ID, UserID: target, Role: domain.OrgRoleMember, JoinedAt: time.Now()})

	if err := uc.TransferOwnership(context.Background(), owner, org.ID, target); err != nil {
		t.Fatalf("transfer failed: %v", err)
	}
	got, _ := orgs.FindByID(context.Background(), org.ID)
	if got.OwnerID != target {
		t.Errorf("owner not moved, got %s", got.OwnerID)
	}
	if r, _ := members.FindRole(context.Background(), org.ID, owner); r != domain.OrgRoleAdmin {
		t.Errorf("old owner must become admin, got %s", r)
	}
	if r, _ := members.FindRole(context.Background(), org.ID, target); r != domain.OrgRoleOwner {
		t.Errorf("target must become owner, got %s", r)
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
