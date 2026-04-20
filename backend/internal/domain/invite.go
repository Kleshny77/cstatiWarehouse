package domain

import (
	"time"

	"github.com/google/uuid"
)

// Invite — многоразовая ссылка-приглашение в организацию.
// Пока активна, любой пользователь может присоединиться по коду.
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

// IsUsable проверяет, можно ли использовать инвайт в момент now.
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
