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

type OrganizationsUseCase struct {
	orgs      OrganizationRepository
	members   OrganizationMemberRepository
	invites   InviteRepository
	inviteGen InviteCodeGenerator
	activity  ActivityRepository
	clock     Clock
}

func NewOrganizationsUseCase(
	orgs OrganizationRepository,
	members OrganizationMemberRepository,
	invites InviteRepository,
	inviteGen InviteCodeGenerator,
	clock Clock,
) *OrganizationsUseCase {
	return &OrganizationsUseCase{
		orgs:      orgs,
		members:   members,
		invites:   invites,
		inviteGen: inviteGen,
		clock:     clock,
	}
}

func (uc *OrganizationsUseCase) WithActivity(activity ActivityRepository) *OrganizationsUseCase {
	uc.activity = activity
	return uc
}

func (uc *OrganizationsUseCase) logActivity(ctx context.Context, orgID, actorID uuid.UUID, kind domain.ActivityKind, targetType string, targetID *uuid.UUID, summary string) {
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

type CreateOrganizationInput struct {
	OwnerID uuid.UUID
	Name    string
}

func (uc *OrganizationsUseCase) Create(ctx context.Context, in CreateOrganizationInput) (*domain.Organization, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	return uc.createWithMembership(ctx, in.OwnerID, name, false)
}

func (uc *OrganizationsUseCase) CreatePersonal(ctx context.Context, ownerID uuid.UUID, ownerName string) (*domain.Organization, error) {
	name := personalOrgName(ownerName)
	return uc.createWithMembership(ctx, ownerID, name, true)
}

func (uc *OrganizationsUseCase) ListMine(ctx context.Context, userID uuid.UUID) ([]OrganizationWithRole, error) {
	return uc.orgs.ListByUser(ctx, userID)
}

func (uc *OrganizationsUseCase) Get(ctx context.Context, userID, orgID uuid.UUID) (*domain.Organization, domain.OrgRole, error) {
	role, err := uc.requireMember(ctx, userID, orgID)
	if err != nil {
		return nil, "", err
	}
	org, err := uc.orgs.FindByID(ctx, orgID)
	if err != nil {
		return nil, "", err
	}
	return org, role, nil
}

type UpdateOrganizationInput struct {
	UserID uuid.UUID
	OrgID  uuid.UUID
	Name   *string
}

func (uc *OrganizationsUseCase) Update(ctx context.Context, in UpdateOrganizationInput) (*domain.Organization, error) {
	role, err := uc.requireMember(ctx, in.UserID, in.OrgID)
	if err != nil {
		return nil, err
	}
	if !role.CanEditOrganization() {
		return nil, domain.ErrForbidden
	}

	patch := OrganizationPatch{}
	if in.Name != nil {
		trimmed := strings.TrimSpace(*in.Name)
		if trimmed == "" {
			return nil, domain.NewValidationError("name must not be empty")
		}
		patch.Name = &trimmed
	}
	if patch.Name == nil {
		return uc.orgs.FindByID(ctx, in.OrgID)
	}
	org, err := uc.orgs.Update(ctx, in.OrgID, patch, uc.clock.Now())
	if err != nil {
		return nil, err
	}
	uc.logActivity(ctx, in.OrgID, in.UserID, domain.ActivityOrganizationUpdated, "organization", &in.OrgID, fmt.Sprintf(i18n.ActivityOrgRenamed, org.Name))
	return org, nil
}

func (uc *OrganizationsUseCase) Delete(ctx context.Context, userID, orgID uuid.UUID) error {
	org, err := uc.orgs.FindByID(ctx, orgID)
	if err != nil {
		return err
	}
	if org.OwnerID != userID {
		return domain.ErrForbidden
	}
	if org.IsPersonal {
		return domain.ErrCannotDeletePersonalOrg
	}
	return uc.orgs.Delete(ctx, orgID)
}

func (uc *OrganizationsUseCase) ListMembers(ctx context.Context, userID, orgID uuid.UUID) ([]MemberWithProfile, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.members.ListWithProfilesByOrganization(ctx, orgID)
}

func (uc *OrganizationsUseCase) RemoveMember(ctx context.Context, actorID, orgID, targetID uuid.UUID) error {
	actorRole, err := uc.requireMember(ctx, actorID, orgID)
	if err != nil {
		return err
	}
	if !actorRole.CanManageMembers() {
		return domain.ErrForbidden
	}
	if actorID == targetID {
		return domain.ErrCannotTargetSelf
	}
	targetRole, err := uc.members.FindRole(ctx, orgID, targetID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return domain.ErrNotFound
		}
		return err
	}
	if targetRole == domain.OrgRoleOwner {
		return domain.ErrCannotTargetOwner
	}
	if actorRole == domain.OrgRoleAdmin && targetRole == domain.OrgRoleAdmin {
		return domain.ErrForbidden
	}
	if err := uc.members.Remove(ctx, orgID, targetID); err != nil {
		return err
	}
	uc.logActivity(ctx, orgID, actorID, domain.ActivityMemberRemoved, "member", &targetID, i18n.ActivityMemberRemoved)
	return nil
}

type ChangeRoleInput struct {
	ActorID  uuid.UUID
	OrgID    uuid.UUID
	TargetID uuid.UUID
	NewRole  domain.OrgRole
}

func (uc *OrganizationsUseCase) ChangeRole(ctx context.Context, in ChangeRoleInput) error {
	if in.NewRole != domain.OrgRoleAdmin && in.NewRole != domain.OrgRoleMember {
		return domain.NewValidationError("role must be admin or member")
	}
	actorRole, err := uc.requireMember(ctx, in.ActorID, in.OrgID)
	if err != nil {
		return err
	}
	if actorRole != domain.OrgRoleOwner && actorRole != domain.OrgRoleAdmin {
		return domain.ErrForbidden
	}
	if in.ActorID == in.TargetID {
		return domain.ErrCannotTargetSelf
	}
	targetRole, err := uc.members.FindRole(ctx, in.OrgID, in.TargetID)
	if err != nil {
		return err
	}
	if targetRole == domain.OrgRoleOwner {
		return domain.ErrCannotTargetOwner
	}
	if targetRole == in.NewRole {
		return nil
	}

	switch actorRole {
	case domain.OrgRoleOwner:
	case domain.OrgRoleAdmin:
		if in.NewRole == domain.OrgRoleMember {
			return domain.ErrForbidden
		}
		if targetRole != domain.OrgRoleMember {
			return domain.ErrForbidden
		}
	default:
		return domain.ErrForbidden
	}

	if err := uc.members.UpdateRole(ctx, in.OrgID, in.TargetID, in.NewRole); err != nil {
		return err
	}
	uc.logActivity(ctx, in.OrgID, in.ActorID, domain.ActivityMemberRoleChanged, "member", &in.TargetID, fmt.Sprintf(i18n.ActivityMemberRoleChanged, string(in.NewRole)))
	return nil
}

func (uc *OrganizationsUseCase) TransferOwnership(ctx context.Context, actorID, orgID, targetID uuid.UUID) error {
	if actorID == targetID {
		return domain.ErrCannotTargetSelf
	}
	org, err := uc.orgs.FindByID(ctx, orgID)
	if err != nil {
		return err
	}
	if org.OwnerID != actorID {
		return domain.ErrForbidden
	}
	if org.IsPersonal {
		return domain.ErrForbidden
	}
	if _, err := uc.members.FindRole(ctx, orgID, targetID); err != nil {
		return err
	}
	now := uc.clock.Now()
	if err := uc.orgs.TransferOwnershipAtomic(ctx, orgID, actorID, targetID, now); err != nil {
		return err
	}
	uc.logActivity(ctx, orgID, actorID, domain.ActivityOwnershipTransferred, "member", &targetID, i18n.ActivityOwnershipTransferred)
	return nil
}

// MARK: invites

type CreateInviteInput struct {
	ActorID   uuid.UUID
	OrgID     uuid.UUID
	ExpiresIn *time.Duration
	MaxUses   *int
}

func (uc *OrganizationsUseCase) CreateInvite(ctx context.Context, in CreateInviteInput) (*domain.Invite, error) {
	role, err := uc.requireMember(ctx, in.ActorID, in.OrgID)
	if err != nil {
		return nil, err
	}
	if !role.CanManageMembers() {
		return nil, domain.ErrForbidden
	}
	if in.MaxUses != nil && *in.MaxUses <= 0 {
		return nil, domain.NewValidationError("max_uses must be positive")
	}
	code, err := uc.inviteGen.Generate()
	if err != nil {
		return nil, err
	}
	now := uc.clock.Now()
	var expires *time.Time
	if in.ExpiresIn != nil {
		t := now.Add(*in.ExpiresIn)
		expires = &t
	}
	invite := &domain.Invite{
		ID:              uuid.New(),
		OrganizationID:  in.OrgID,
		Code:            code,
		CreatedByUserID: in.ActorID,
		CreatedAt:       now,
		ExpiresAt:       expires,
		MaxUses:         in.MaxUses,
	}
	if err := uc.invites.Create(ctx, invite); err != nil {
		return nil, err
	}
	return invite, nil
}

func (uc *OrganizationsUseCase) ListInvites(ctx context.Context, actorID, orgID uuid.UUID) ([]domain.Invite, error) {
	role, err := uc.requireMember(ctx, actorID, orgID)
	if err != nil {
		return nil, err
	}
	if !role.CanManageMembers() {
		return nil, domain.ErrForbidden
	}
	return uc.invites.ListByOrganization(ctx, orgID)
}

func (uc *OrganizationsUseCase) RevokeInvite(ctx context.Context, actorID, orgID, inviteID uuid.UUID) error {
	role, err := uc.requireMember(ctx, actorID, orgID)
	if err != nil {
		return err
	}
	if !role.CanManageMembers() {
		return domain.ErrForbidden
	}
	invite, err := uc.invites.FindByID(ctx, inviteID)
	if err != nil {
		return err
	}
	if invite.OrganizationID != orgID {
		return domain.ErrInviteWrongOrg
	}
	if invite.RevokedAt != nil {
		return nil
	}
	return uc.invites.Revoke(ctx, inviteID, uc.clock.Now())
}

func (uc *OrganizationsUseCase) JoinByCode(ctx context.Context, userID uuid.UUID, code string) (*domain.Organization, domain.OrgRole, error) {
	code = strings.TrimSpace(strings.ToUpper(code))
	if code == "" {
		return nil, "", domain.NewValidationError("code must not be empty")
	}
	invite, err := uc.invites.FindByCode(ctx, code)
	if err != nil {
		return nil, "", err
	}
	now := uc.clock.Now()
	if !invite.IsUsable(now) {
		return nil, "", domain.ErrInviteNotUsable
	}
	if role, err := uc.members.FindRole(ctx, invite.OrganizationID, userID); err == nil {
		org, err := uc.orgs.FindByID(ctx, invite.OrganizationID)
		if err != nil {
			return nil, "", err
		}
		return org, role, nil
	} else if !errors.Is(err, domain.ErrNotFound) {
		return nil, "", err
	}
	member := &domain.OrganizationMember{
		OrganizationID: invite.OrganizationID,
		UserID:         userID,
		Role:           domain.OrgRoleMember,
		JoinedAt:       now,
	}
	if err := uc.members.Add(ctx, member); err != nil {
		return nil, "", err
	}
	if err := uc.invites.IncrementUsed(ctx, invite.ID); err != nil {
		return nil, "", err
	}
	org, err := uc.orgs.FindByID(ctx, invite.OrganizationID)
	if err != nil {
		return nil, "", err
	}
	uc.logActivity(ctx, invite.OrganizationID, userID, domain.ActivityMemberAdded, "member", &userID, i18n.ActivityMemberJoined)
	return org, domain.OrgRoleMember, nil
}

func (uc *OrganizationsUseCase) Leave(ctx context.Context, userID, orgID uuid.UUID) error {
	role, err := uc.requireMember(ctx, userID, orgID)
	if err != nil {
		return err
	}
	if role == domain.OrgRoleOwner {
		return domain.ErrOwnerCannotLeave
	}
	return uc.members.Remove(ctx, orgID, userID)
}

// MARK: private helpers

func (uc *OrganizationsUseCase) createWithMembership(ctx context.Context, ownerID uuid.UUID, name string, isPersonal bool) (*domain.Organization, error) {
	now := uc.clock.Now()
	org := &domain.Organization{
		ID:         uuid.New(),
		Name:       name,
		OwnerID:    ownerID,
		IsPersonal: isPersonal,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if err := uc.orgs.Create(ctx, org); err != nil {
		return nil, err
	}
	member := &domain.OrganizationMember{
		OrganizationID: org.ID,
		UserID:         ownerID,
		Role:           domain.OrgRoleOwner,
		JoinedAt:       now,
	}
	if err := uc.members.Add(ctx, member); err != nil {
		_ = uc.orgs.Delete(ctx, org.ID)
		return nil, err
	}
	return org, nil
}

func (uc *OrganizationsUseCase) requireMember(ctx context.Context, userID, orgID uuid.UUID) (domain.OrgRole, error) {
	role, err := uc.members.FindRole(ctx, orgID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return "", domain.ErrForbidden
		}
		return "", err
	}
	return role, nil
}

func personalOrgName(ownerName string) string {
	trimmed := strings.TrimSpace(ownerName)
	if trimmed == "" {
		return i18n.DefaultWarehouseName
	}
	return fmt.Sprintf(i18n.DefaultWarehouseNameWithOwner, trimmed)
}
