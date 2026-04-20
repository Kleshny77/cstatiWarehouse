package domain

import (
	"time"

	"github.com/google/uuid"
)

// OrgRole — роль пользователя в организации.
type OrgRole string

const (
	OrgRoleOwner  OrgRole = "owner"
	OrgRoleAdmin  OrgRole = "admin"
	OrgRoleMember OrgRole = "member"
)

func IsValidOrgRole(r OrgRole) bool {
	switch r {
	case OrgRoleOwner, OrgRoleAdmin, OrgRoleMember:
		return true
	}
	return false
}

// CanManageMembers возвращает true для ролей, которые могут
// приглашать/удалять участников и менять роли (owner, admin).
func (r OrgRole) CanManageMembers() bool {
	return r == OrgRoleOwner || r == OrgRoleAdmin
}

// CanEditOrganization — может редактировать название организации и её настройки.
func (r OrgRole) CanEditOrganization() bool {
	return r == OrgRoleOwner || r == OrgRoleAdmin
}

// Organization — сущность организации. Все айтемы склада принадлежат организации.
// Персональный склад моделируется как организация с IsPersonal=true и одним участником.
type Organization struct {
	ID         uuid.UUID
	Name       string
	OwnerID    uuid.UUID
	IsPersonal bool
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// OrganizationMember — запись о членстве пользователя в организации.
type OrganizationMember struct {
	OrganizationID uuid.UUID
	UserID         uuid.UUID
	Role           OrgRole
	JoinedAt       time.Time
}
