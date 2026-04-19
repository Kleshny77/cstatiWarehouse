package domain

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID
	Email        string
	Name         string
	AvatarURL    *string
	PasswordHash *string
	TelegramSub  *string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
