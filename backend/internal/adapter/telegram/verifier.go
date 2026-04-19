package telegram

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	jwtlib "github.com/golang-jwt/jwt/v5"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type JWKSVerifier struct {
	clientID string
	issuer   string
	kf       keyfunc.Keyfunc
}

func NewJWKSVerifier(ctx context.Context, jwksURL, issuer, clientID string) (*JWKSVerifier, error) {
	kf, err := keyfunc.NewDefaultCtx(ctx, []string{jwksURL})
	if err != nil {
		return nil, fmt.Errorf("init JWKS: %w", err)
	}
	return &JWKSVerifier{
		clientID: clientID,
		issuer:   issuer,
		kf:       kf,
	}, nil
}

type telegramClaims struct {
	jwtlib.RegisteredClaims
	Name              string `json:"name"`
	PreferredUsername string `json:"preferred_username"`
	PhoneNumber       string `json:"phone_number"`
	Email             string `json:"email"`
	Picture           string `json:"picture"`
}

func (v *JWKSVerifier) Verify(ctx context.Context, idToken string) (domain.TelegramClaims, error) {
	claims := &telegramClaims{}
	parser := jwtlib.NewParser(
		jwtlib.WithValidMethods([]string{"RS256", "ES256"}),
		jwtlib.WithIssuer(v.issuer),
		jwtlib.WithAudience(v.clientID),
		jwtlib.WithExpirationRequired(),
		jwtlib.WithTimeFunc(func() time.Time { return time.Now() }),
	)
	token, err := parser.ParseWithClaims(idToken, claims, v.kf.Keyfunc)
	if err != nil {
		return domain.TelegramClaims{}, fmt.Errorf("%w: %v", domain.ErrUnauthorized, err)
	}
	if !token.Valid {
		return domain.TelegramClaims{}, domain.ErrUnauthorized
	}
	if claims.Subject == "" {
		return domain.TelegramClaims{}, errors.New("telegram id_token missing sub claim")
	}

	out := domain.TelegramClaims{Sub: claims.Subject}
	if claims.Name != "" {
		name := claims.Name
		out.Name = &name
	}
	if claims.PreferredUsername != "" {
		username := claims.PreferredUsername
		out.PreferredUsername = &username
	}
	if claims.PhoneNumber != "" {
		phone := claims.PhoneNumber
		out.PhoneNumber = &phone
	}
	if claims.Email != "" {
		email := claims.Email
		out.Email = &email
	}
	if claims.Picture != "" {
		pic := claims.Picture
		out.PictureURL = &pic
	}
	return out, nil
}
