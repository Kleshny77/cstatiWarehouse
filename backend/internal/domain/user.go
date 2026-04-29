package domain

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID
	Email        string
	Name         string
	LastName     string
	AvatarURL    *string
	PasswordHash *string
	TelegramSub  *string
	AppleSub     *string
	GoogleSub    *string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

func (u *User) FullName() string {
	if u.LastName == "" {
		return u.Name
	}
	return u.Name + " " + u.LastName
}
