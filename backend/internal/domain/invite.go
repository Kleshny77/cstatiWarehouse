package domain

import (
	"time"

	"github.com/google/uuid"
)

type Invite struct {
	ID              uuid.UUID
	OrganizationID  uuid.UUID
	Code            string
	CreatedByUserID uuid.UUID
	CreatedAt       time.Time
	ExpiresAt       *time.Time
	MaxUses         *int
	UsedCount       int
	RevokedAt       *time.Time
}

func (i *Invite) IsUsable(now time.Time) bool {
	if i.RevokedAt != nil {
		return false
	}
	if i.ExpiresAt != nil && !now.Before(*i.ExpiresAt) {
		return false
	}
	if i.MaxUses != nil && i.UsedCount >= *i.MaxUses {
		return false
	}
	return true
}
