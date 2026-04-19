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

// AuthTokens — ответ клиенту при login/register/refresh.
type AuthTokens struct {
	AccessToken       string
	AccessExpiresAt   time.Time
	RefreshToken      string
	RefreshExpiresAt  time.Time
}

// TelegramClaims — извлечённые из валидного id_token данные Telegram-пользователя.
type TelegramClaims struct {
	Sub               string
	Name              *string
	PreferredUsername *string
	PhoneNumber       *string
	Email             *string
	PictureURL        *string
}
