package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func newAuthUC(t *testing.T) (*AuthUseCase, *fakeUserRepo, *fakeRefreshRepo, *fakeClock, *fakeTelegramVerifier) {
	t.Helper()
	users := newFakeUserRepo()
	refresh := newFakeRefreshRepo()
	clock := newFakeClock(time.Date(2026, time.April, 17, 12, 0, 0, 0, time.UTC))
	verifier := &fakeTelegramVerifier{}
	uc := NewAuthUseCase(
		users,
		refresh,
		&fakeHasher{},
		&fakeTokenIssuer{ttl: 15 * time.Minute},
		&fakeRefreshGen{},
		verifier,
		clock,
		AuthConfig{
			RefreshTTL:         24 * time.Hour,
			TelegramConfigured: true,
		},
	)
	return uc, users, refresh, clock, verifier
}

func TestAuthUseCase_Register_Success(t *testing.T) {
	uc, users, refresh, _, _ := newAuthUC(t)
	ctx := context.Background()

	user, tokens, err := uc.Register(ctx, RegisterInput{
		Name: "Артём", Email: "TEST@example.com", Password: "supersecret",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Email != "test@example.com" {
		t.Errorf("email not normalized, got %q", user.Email)
	}
	if user.PasswordHash == nil || *user.PasswordHash != "hash:supersecret" {
		t.Errorf("password hash not set correctly: %+v", user.PasswordHash)
	}
	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Error("tokens must be issued")
	}
	if len(users.users) != 1 {
		t.Errorf("expected 1 user in repo, got %d", len(users.users))
	}
	if len(refresh.tokens) != 1 {
		t.Errorf("expected 1 refresh token stored, got %d", len(refresh.tokens))
	}
}

func TestAuthUseCase_Register_Validation(t *testing.T) {
	uc, _, _, _, _ := newAuthUC(t)
	ctx := context.Background()

	cases := []struct {
		name string
		in   RegisterInput
	}{
		{"empty name", RegisterInput{Name: "  ", Email: "a@b.co", Password: "supersecret"}},
		{"bad email", RegisterInput{Name: "A", Email: "not-email", Password: "supersecret"}},
		{"short password", RegisterInput{Name: "A", Email: "a@b.co", Password: "short"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, _, err := uc.Register(ctx, tc.in)
			if !errors.Is(err, domain.ErrValidation) {
				t.Errorf("expected ErrValidation, got %v", err)
			}
		})
	}
}

func TestAuthUseCase_Register_EmailTaken(t *testing.T) {
	uc, _, _, _, _ := newAuthUC(t)
	ctx := context.Background()

	in := RegisterInput{Name: "A", Email: "dup@example.com", Password: "supersecret"}
	if _, _, err := uc.Register(ctx, in); err != nil {
		t.Fatalf("first register failed: %v", err)
	}
	if _, _, err := uc.Register(ctx, in); !errors.Is(err, domain.ErrEmailAlreadyUsed) {
		t.Errorf("expected ErrEmailAlreadyUsed, got %v", err)
	}
}

func TestAuthUseCase_Login_HappyAndSad(t *testing.T) {
	uc, _, _, _, _ := newAuthUC(t)
	ctx := context.Background()

	if _, _, err := uc.Register(ctx, RegisterInput{Name: "A", Email: "u@e.co", Password: "supersecret"}); err != nil {
		t.Fatalf("register failed: %v", err)
	}

	if _, _, err := uc.Login(ctx, LoginInput{Email: "u@e.co", Password: "supersecret"}); err != nil {
		t.Errorf("login happy path failed: %v", err)
	}

	if _, _, err := uc.Login(ctx, LoginInput{Email: "u@e.co", Password: "wrong"}); !errors.Is(err, domain.ErrInvalidCreds) {
		t.Errorf("expected ErrInvalidCreds on wrong password, got %v", err)
	}
	if _, _, err := uc.Login(ctx, LoginInput{Email: "unknown@e.co", Password: "supersecret"}); !errors.Is(err, domain.ErrInvalidCreds) {
		t.Errorf("expected ErrInvalidCreds on unknown email, got %v", err)
	}
}

func TestAuthUseCase_Refresh_Rotation(t *testing.T) {
	uc, _, refresh, clock, _ := newAuthUC(t)
	ctx := context.Background()

	_, tokens, err := uc.Register(ctx, RegisterInput{Name: "A", Email: "u@e.co", Password: "supersecret"})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	clock.Advance(time.Minute)
	_, newTokens, err := uc.Refresh(ctx, tokens.RefreshToken)
	if err != nil {
		t.Fatalf("refresh failed: %v", err)
	}
	if newTokens.RefreshToken == tokens.RefreshToken {
		t.Error("refresh token must be rotated")
	}

	if _, _, err := uc.Refresh(ctx, tokens.RefreshToken); !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("old refresh token must be invalid, got %v", err)
	}

	if len(refresh.tokens) != 2 {
		t.Errorf("expected 2 refresh tokens stored (old revoked + new), got %d", len(refresh.tokens))
	}
}

func TestAuthUseCase_Refresh_Expired(t *testing.T) {
	uc, _, _, clock, _ := newAuthUC(t)
	ctx := context.Background()

	_, tokens, err := uc.Register(ctx, RegisterInput{Name: "A", Email: "u@e.co", Password: "supersecret"})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	clock.Advance(48 * time.Hour)
	if _, _, err := uc.Refresh(ctx, tokens.RefreshToken); !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("expected ErrUnauthorized for expired token, got %v", err)
	}
}

func TestAuthUseCase_Logout_RevokesToken(t *testing.T) {
	uc, _, _, _, _ := newAuthUC(t)
	ctx := context.Background()

	_, tokens, err := uc.Register(ctx, RegisterInput{Name: "A", Email: "u@e.co", Password: "supersecret"})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	if err := uc.Logout(ctx, tokens.RefreshToken); err != nil {
		t.Fatalf("logout failed: %v", err)
	}
	if _, _, err := uc.Refresh(ctx, tokens.RefreshToken); !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("after logout refresh must be unauthorized, got %v", err)
	}

	if err := uc.Logout(ctx, "never-existed"); err != nil {
		t.Errorf("logout of unknown token must be no-op, got %v", err)
	}
}

func TestAuthUseCase_Telegram_NotConfigured(t *testing.T) {
	uc, _, _, _, _ := newAuthUC(t)
	uc.cfg.TelegramConfigured = false
	uc.telegram = nil

	if _, _, err := uc.LoginWithTelegram(context.Background(), "token"); !errors.Is(err, domain.ErrTelegramDisabled) {
		t.Errorf("expected ErrTelegramDisabled, got %v", err)
	}
}

func TestAuthUseCase_Telegram_CreatesUser(t *testing.T) {
	uc, users, _, _, verifier := newAuthUC(t)
	name := "Tg User"
	username := "tg_user"
	verifier.result = domain.TelegramClaims{Sub: "42", Name: &name, PreferredUsername: &username}

	user, tokens, err := uc.LoginWithTelegram(context.Background(), "any")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.TelegramSub == nil || *user.TelegramSub != "42" {
		t.Errorf("telegram sub not linked: %+v", user.TelegramSub)
	}
	if user.Email != "tg_user@telegram.local" {
		t.Errorf("unexpected synthetic email: %s", user.Email)
	}
	if tokens.AccessToken == "" {
		t.Error("tokens must be issued")
	}
	if len(users.users) != 1 {
		t.Errorf("expected 1 user created, got %d", len(users.users))
	}
}

func TestAuthUseCase_Telegram_ReusesExistingByTelegramSub(t *testing.T) {
	uc, _, _, _, verifier := newAuthUC(t)
	verifier.result = domain.TelegramClaims{Sub: "42"}

	first, _, err := uc.LoginWithTelegram(context.Background(), "any")
	if err != nil {
		t.Fatalf("first telegram login failed: %v", err)
	}
	second, _, err := uc.LoginWithTelegram(context.Background(), "any")
	if err != nil {
		t.Fatalf("second telegram login failed: %v", err)
	}
	if first.ID != second.ID {
		t.Error("same telegram sub must return same user")
	}
}

func TestAuthUseCase_Telegram_VerifierError(t *testing.T) {
	uc, _, _, _, verifier := newAuthUC(t)
	verifier.err = errors.New("boom")

	if _, _, err := uc.LoginWithTelegram(context.Background(), "any"); err == nil {
		t.Error("expected error from verifier")
	}
}
