package domain

import (
	"time"

	"github.com/google/uuid"
)

type RefreshToken struct {
	TokenHash string
	UserID    uuid.UUID
	ExpiresAt time.Time
	RevokedAt *time.Time
	CreatedAt time.Time
}

type AuthTokens struct {
	AccessToken      string
	AccessExpiresAt  time.Time
	RefreshToken     string
	RefreshExpiresAt time.Time
}

type TelegramClaims struct {
	Sub               string
	Name              *string
	PreferredUsername *string
	PhoneNumber       *string
	Email             *string
	PictureURL        *string
}
