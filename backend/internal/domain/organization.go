package domain

import (
	"time"

	"github.com/google/uuid"
)

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

func (r OrgRole) CanManageMembers() bool {
	return r == OrgRoleOwner || r == OrgRoleAdmin
}

func (r OrgRole) CanEditOrganization() bool {
	return r == OrgRoleOwner || r == OrgRoleAdmin
}

type Organization struct {
	ID         uuid.UUID
	Name       string
	OwnerID    uuid.UUID
	IsPersonal bool
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type OrganizationMember struct {
	OrganizationID uuid.UUID
	UserID         uuid.UUID
	Role           OrgRole
	JoinedAt       time.Time
}
