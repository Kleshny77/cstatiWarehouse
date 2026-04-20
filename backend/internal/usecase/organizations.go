package usecase

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// OrganizationsUseCase — бизнес-логика работы с организациями и участниками.
type OrganizationsUseCase struct {
	orgs    OrganizationRepository
	members OrganizationMemberRepository
	clock   Clock
}

func NewOrganizationsUseCase(orgs OrganizationRepository, members OrganizationMemberRepository, clock Clock) *OrganizationsUseCase {
	return &OrganizationsUseCase{orgs: orgs, members: members, clock: clock}
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
	return uc.orgs.Update(ctx, in.OrgID, patch, uc.clock.Now())
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

// ListMembers возвращает всех участников организации. Доступно любому её участнику.
func (uc *OrganizationsUseCase) ListMembers(ctx context.Context, userID, orgID uuid.UUID) ([]domain.OrganizationMember, error) {
	if _, err := uc.requireMember(ctx, userID, orgID); err != nil {
		return nil, err
	}
	return uc.members.ListByOrganization(ctx, orgID)
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
