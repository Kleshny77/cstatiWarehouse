package usecase

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type AuthConfig struct {
	RefreshTTL        time.Duration
	TelegramConfigured bool
}

type AuthUseCase struct {
	users         UserRepository
	refreshTokens RefreshTokenRepository
	hasher        PasswordHasher
	tokens        TokenIssuer
	refreshGen    RefreshTokenGenerator
	telegram      TelegramVerifier
	clock         Clock
	cfg           AuthConfig
}

func NewAuthUseCase(
	users UserRepository,
	refreshTokens RefreshTokenRepository,
	hasher PasswordHasher,
	tokens TokenIssuer,
	refreshGen RefreshTokenGenerator,
	telegram TelegramVerifier,
	clock Clock,
	cfg AuthConfig,
) *AuthUseCase {
	return &AuthUseCase{
		users:         users,
		refreshTokens: refreshTokens,
		hasher:        hasher,
		tokens:        tokens,
		refreshGen:    refreshGen,
		telegram:      telegram,
		clock:         clock,
		cfg:           cfg,
	}
}

type RegisterInput struct {
	Name      string
	Email     string
	Password  string
	AvatarURL *string
}

func (uc *AuthUseCase) Register(ctx context.Context, in RegisterInput) (*domain.User, domain.AuthTokens, error) {
	name := strings.TrimSpace(in.Name)
	email := normalizeEmail(in.Email)

	if name == "" {
		return nil, domain.AuthTokens{}, domain.NewValidationError("name must not be empty")
	}
	if err := validateEmail(email); err != nil {
		return nil, domain.AuthTokens{}, err
	}
	if err := validatePassword(in.Password); err != nil {
		return nil, domain.AuthTokens{}, err
	}

	if existing, err := uc.users.FindByEmail(ctx, email); err != nil && !errors.Is(err, domain.ErrNotFound) {
		return nil, domain.AuthTokens{}, err
	} else if existing != nil {
		return nil, domain.AuthTokens{}, domain.ErrEmailAlreadyUsed
	}

	hash, err := uc.hasher.Hash(in.Password)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}

	now := uc.clock.Now()
	var avatar *string
	if in.AvatarURL != nil {
		trimmed := strings.TrimSpace(*in.AvatarURL)
		if trimmed != "" {
			avatar = &trimmed
		}
	}
	user := &domain.User{
		ID:           uuid.New(),
		Email:        email,
		Name:         name,
		AvatarURL:    avatar,
		PasswordHash: &hash,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := uc.users.Create(ctx, user); err != nil {
		return nil, domain.AuthTokens{}, err
	}

	tokens, err := uc.issueTokens(ctx, user.ID, now)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}
	return user, tokens, nil
}

type LoginInput struct {
	Email    string
	Password string
}

func (uc *AuthUseCase) Login(ctx context.Context, in LoginInput) (*domain.User, domain.AuthTokens, error) {
	email := normalizeEmail(in.Email)
	if email == "" || in.Password == "" {
		return nil, domain.AuthTokens{}, domain.ErrInvalidCreds
	}

	user, err := uc.users.FindByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.AuthTokens{}, domain.ErrInvalidCreds
		}
		return nil, domain.AuthTokens{}, err
	}
	if user.PasswordHash == nil {
		return nil, domain.AuthTokens{}, domain.ErrInvalidCreds
	}
	if err := uc.hasher.Verify(*user.PasswordHash, in.Password); err != nil {
		return nil, domain.AuthTokens{}, domain.ErrInvalidCreds
	}

	tokens, err := uc.issueTokens(ctx, user.ID, uc.clock.Now())
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}
	return user, tokens, nil
}

// LoginWithTelegram валидирует id_token, находит или создаёт пользователя по Telegram sub.
func (uc *AuthUseCase) LoginWithTelegram(ctx context.Context, idToken string) (*domain.User, domain.AuthTokens, error) {
	if !uc.cfg.TelegramConfigured || uc.telegram == nil {
		return nil, domain.AuthTokens{}, domain.ErrTelegramDisabled
	}
	if strings.TrimSpace(idToken) == "" {
		return nil, domain.AuthTokens{}, domain.NewValidationError("id_token must not be empty")
	}

	claims, err := uc.telegram.Verify(ctx, idToken)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}
	if claims.Sub == "" {
		return nil, domain.AuthTokens{}, domain.ErrUnauthorized
	}

	now := uc.clock.Now()

	if existing, err := uc.users.FindByTelegramSub(ctx, claims.Sub); err == nil {
		refreshed, err := uc.syncTelegramProfile(ctx, existing, claims, now)
		if err != nil {
			return nil, domain.AuthTokens{}, err
		}
		tokens, err := uc.issueTokens(ctx, refreshed.ID, now)
		if err != nil {
			return nil, domain.AuthTokens{}, err
		}
		return refreshed, tokens, nil
	} else if !errors.Is(err, domain.ErrNotFound) {
		return nil, domain.AuthTokens{}, err
	}

	email := syntheticTelegramEmail(claims)
	name := telegramDisplayName(claims)
	sub := claims.Sub
	user := &domain.User{
		ID:          uuid.New(),
		Email:       email,
		Name:        name,
		AvatarURL:   copyPtr(claims.PictureURL),
		TelegramSub: &sub,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := uc.users.Create(ctx, user); err != nil {
		return nil, domain.AuthTokens{}, err
	}

	tokens, err := uc.issueTokens(ctx, user.ID, now)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}
	return user, tokens, nil
}

// Refresh ротирует refresh-токен: текущий ревокается, выпускается новая пара.
func (uc *AuthUseCase) Refresh(ctx context.Context, refreshToken string) (*domain.User, domain.AuthTokens, error) {
	if refreshToken == "" {
		return nil, domain.AuthTokens{}, domain.ErrUnauthorized
	}

	hash := uc.refreshGen.Hash(refreshToken)
	stored, err := uc.refreshTokens.FindByHash(ctx, hash)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.AuthTokens{}, domain.ErrUnauthorized
		}
		return nil, domain.AuthTokens{}, err
	}

	now := uc.clock.Now()
	if stored.RevokedAt != nil || !now.Before(stored.ExpiresAt) {
		return nil, domain.AuthTokens{}, domain.ErrUnauthorized
	}

	user, err := uc.users.FindByID(ctx, stored.UserID)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}

	if err := uc.refreshTokens.Revoke(ctx, hash, now); err != nil {
		return nil, domain.AuthTokens{}, err
	}

	tokens, err := uc.issueTokens(ctx, user.ID, now)
	if err != nil {
		return nil, domain.AuthTokens{}, err
	}
	return user, tokens, nil
}

// Logout ревокает переданный refresh-токен. Если его нет — тихий no-op,
// чтобы нельзя было по ответу различать существующие/несуществующие токены.
func (uc *AuthUseCase) Logout(ctx context.Context, refreshToken string) error {
	if refreshToken == "" {
		return nil
	}
	hash := uc.refreshGen.Hash(refreshToken)
	err := uc.refreshTokens.Revoke(ctx, hash, uc.clock.Now())
	if errors.Is(err, domain.ErrNotFound) {
		return nil
	}
	return err
}

func (uc *AuthUseCase) CurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error) {
	return uc.users.FindByID(ctx, userID)
}

// UpdateProfileInput — частичное обновление своего профиля из клиента.
// Поле nil означает "не менять".
type UpdateProfileInput struct {
	Name      *string
	AvatarURL *string
}

// UpdateProfile применяет патч к собственному профилю. Возвращает актуальную версию пользователя.
func (uc *AuthUseCase) UpdateProfile(ctx context.Context, userID uuid.UUID, in UpdateProfileInput) (*domain.User, error) {
	patch := UserProfileUpdate{}
	if in.Name != nil {
		trimmed := strings.TrimSpace(*in.Name)
		if trimmed == "" {
			return nil, domain.NewValidationError("name must not be empty")
		}
		patch.Name = &trimmed
	}
	if in.AvatarURL != nil {
		trimmed := strings.TrimSpace(*in.AvatarURL)
		patch.AvatarURL = &trimmed
	}
	if patch.Name == nil && patch.AvatarURL == nil {
		return uc.users.FindByID(ctx, userID)
	}
	return uc.users.UpdateProfile(ctx, userID, patch, uc.clock.Now())
}

// syncTelegramProfile подтягивает свежие name/avatar из claims на каждый вход.
// Сохраняем только если данные реально поменялись и/или поле пустое.
func (uc *AuthUseCase) syncTelegramProfile(ctx context.Context, user *domain.User, claims domain.TelegramClaims, now time.Time) (*domain.User, error) {
	patch := UserProfileUpdate{}

	newName := telegramDisplayName(claims)
	if newName != "" && newName != user.Name {
		n := newName
		patch.Name = &n
	}

	if claims.PictureURL != nil {
		current := ""
		if user.AvatarURL != nil {
			current = *user.AvatarURL
		}
		if *claims.PictureURL != current {
			pic := *claims.PictureURL
			patch.AvatarURL = &pic
		}
	}

	if patch.Name == nil && patch.AvatarURL == nil {
		return user, nil
	}
	return uc.users.UpdateProfile(ctx, user.ID, patch, now)
}

func copyPtr(s *string) *string {
	if s == nil {
		return nil
	}
	v := *s
	return &v
}

// MARK: private helpers

func (uc *AuthUseCase) issueTokens(ctx context.Context, userID uuid.UUID, now time.Time) (domain.AuthTokens, error) {
	accessToken, accessExp, err := uc.tokens.IssueAccessToken(userID, now)
	if err != nil {
		return domain.AuthTokens{}, err
	}

	plaintext, hash, err := uc.refreshGen.Generate()
	if err != nil {
		return domain.AuthTokens{}, err
	}
	refreshExp := now.Add(uc.cfg.RefreshTTL)

	if err := uc.refreshTokens.Create(ctx, &domain.RefreshToken{
		TokenHash: hash,
		UserID:    userID,
		ExpiresAt: refreshExp,
		CreatedAt: now,
	}); err != nil {
		return domain.AuthTokens{}, err
	}

	return domain.AuthTokens{
		AccessToken:      accessToken,
		AccessExpiresAt:  accessExp,
		RefreshToken:     plaintext,
		RefreshExpiresAt: refreshExp,
	}, nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validateEmail(email string) error {
	if email == "" {
		return domain.NewValidationError("email must not be empty")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return domain.NewValidationError("email is not a valid address")
	}
	return nil
}

func validatePassword(password string) error {
	if len(password) < 8 {
		return domain.NewValidationError("password must be at least 8 characters long")
	}
	return nil
}

func syntheticTelegramEmail(c domain.TelegramClaims) string {
	if c.PreferredUsername != nil && *c.PreferredUsername != "" {
		return strings.ToLower(*c.PreferredUsername) + "@telegram.local"
	}
	return "tg_" + c.Sub + "@telegram.local"
}

func telegramDisplayName(c domain.TelegramClaims) string {
	if c.Name != nil && strings.TrimSpace(*c.Name) != "" {
		return *c.Name
	}
	if c.PreferredUsername != nil && *c.PreferredUsername != "" {
		return "@" + *c.PreferredUsername
	}
	return "Telegram user"
}
