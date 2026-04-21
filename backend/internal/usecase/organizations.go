package usecase

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// OrganizationsUseCase — бизнес-логика работы с организациями и участниками.
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

// WithActivity подключает репозиторий журнала. nil отключает логирование
// (удобно для тестов и опциональной раскатки). Возвращает тот же *OrganizationsUseCase.
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

// CreateOrganizationInput — параметры для ручного создания организации пользователем.
type CreateOrganizationInput struct {
	OwnerID uuid.UUID
	Name    string
}

// Create создаёт новую организацию и делает пользователя её единственным участником с ролью owner.
func (uc *OrganizationsUseCase) Create(ctx context.Context, in CreateOrganizationInput) (*domain.Organization, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, domain.NewValidationError("name must not be empty")
	}
	return uc.createWithMembership(ctx, in.OwnerID, name, false)
}

// CreatePersonal создаёт личную организацию (флаг IsPersonal=true) при регистрации.
// Реализует порт PersonalOrgCreator.
func (uc *OrganizationsUseCase) CreatePersonal(ctx context.Context, ownerID uuid.UUID, ownerName string) (*domain.Organization, error) {
	name := personalOrgName(ownerName)
	return uc.createWithMembership(ctx, ownerID, name, true)
}

// ListMine возвращает все организации, в которых состоит пользователь, с его ролью.
func (uc *OrganizationsUseCase) ListMine(ctx context.Context, userID uuid.UUID) ([]OrganizationWithRole, error) {
	return uc.orgs.ListByUser(ctx, userID)
}

// Get возвращает организацию, если пользователь — её участник.
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

// UpdateOrganizationInput — патч для редактирования организации.
type UpdateOrganizationInput struct {
	UserID uuid.UUID
	OrgID  uuid.UUID
	Name   *string
}

// Update редактирует организацию. Доступно owner и admin.
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
	uc.logActivity(ctx, in.OrgID, in.UserID, domain.ActivityOrganizationUpdated, "organization", &in.OrgID, "организация переименована в «"+org.Name+"»")
	return org, nil
}

// Delete удаляет организацию. Доступно только owner. Для персональной — запрещено.
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

// ListMembers возвращает всех участников организации с их профилями.
// Доступно любому участнику организации.
func (uc *OrganizationsUseCase) ListMembers(ctx context.Context, userID, orgID uuid.UUID) ([]MemberWithProfile, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.members.ListWithProfilesByOrganization(ctx, orgID)
}

// RemoveMember удаляет участника из организации. Доступно owner и admin.
// Нельзя удалить owner; self-удаление идёт через Leave.
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
	// admin не может удалить другого admin — только owner может понижать admin'ов.
	if actorRole == domain.OrgRoleAdmin && targetRole == domain.OrgRoleAdmin {
		return domain.ErrForbidden
	}
	if err := uc.members.Remove(ctx, orgID, targetID); err != nil {
		return err
	}
	uc.logActivity(ctx, orgID, actorID, domain.ActivityMemberRemoved, "member", &targetID, "участник удалён из организации")
	return nil
}

// ChangeRoleInput — изменение роли участника (только между admin и member).
// Передача владения делается отдельным методом TransferOwnership.
type ChangeRoleInput struct {
	ActorID  uuid.UUID
	OrgID    uuid.UUID
	TargetID uuid.UUID
	NewRole  domain.OrgRole
}

// ChangeRole меняет роль участника. Только owner может менять роли.
// admin → member или member → admin. Нельзя трогать owner.
func (uc *OrganizationsUseCase) ChangeRole(ctx context.Context, in ChangeRoleInput) error {
	if in.NewRole != domain.OrgRoleAdmin && in.NewRole != domain.OrgRoleMember {
		return domain.NewValidationError("role must be admin or member")
	}
	actorRole, err := uc.requireMember(ctx, in.ActorID, in.OrgID)
	if err != nil {
		return err
	}
	if actorRole != domain.OrgRoleOwner {
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
	if err := uc.members.UpdateRole(ctx, in.OrgID, in.TargetID, in.NewRole); err != nil {
		return err
	}
	uc.logActivity(ctx, in.OrgID, in.ActorID, domain.ActivityMemberRoleChanged, "member", &in.TargetID, "роль участника изменена на "+string(in.NewRole))
	return nil
}

// TransferOwnership передаёт владение другой роли. Только текущий owner может.
// Новый владелец становится owner, старый — admin.
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
	uc.logActivity(ctx, orgID, actorID, domain.ActivityOwnershipTransferred, "member", &targetID, "владелец организации передал права новому владельцу")
	return nil
}

// MARK: invites

// CreateInviteInput — параметры нового инвайта.
// ExpiresIn == nil → без срока; MaxUses == nil → без лимита.
type CreateInviteInput struct {
	ActorID   uuid.UUID
	OrgID     uuid.UUID
	ExpiresIn *time.Duration
	MaxUses   *int
}

// CreateInvite создаёт инвайт-ссылку. Доступно owner и admin.
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

// ListInvites возвращает инвайты организации. Доступно owner и admin.
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

// RevokeInvite отзывает инвайт. Доступно owner и admin организации-владельца инвайта.
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

// JoinByCode добавляет пользователя в организацию по коду инвайта.
// Возвращает организацию и роль, чтобы клиент сразу мог показать её в списке.
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
	// Уже участник?
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
	uc.logActivity(ctx, invite.OrganizationID, userID, domain.ActivityMemberAdded, "member", &userID, "новый участник присоединился к организации")
	return org, domain.OrgRoleMember, nil
}

// Leave позволяет участнику самому покинуть организацию. Owner так выйти не может —
// он должен сначала передать владение или удалить организацию.
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
		// Если membership не создался — откатываем организацию, чтобы не оставлять мусор.
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
		return "Мой склад"
	}
	return "Склад " + trimmed
}
