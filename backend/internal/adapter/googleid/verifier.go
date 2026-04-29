package googleid

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	jwtlib "github.com/golang-jwt/jwt/v5"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type Verifier struct {
	clientID string
	kf       keyfunc.Keyfunc
}

func NewVerifier(ctx context.Context, clientID string) (*Verifier, error) {
	kf, err := keyfunc.NewDefaultCtx(ctx, []string{"https://www.googleapis.com/oauth2/v3/certs"})
	if err != nil {
		return nil, fmt.Errorf("init Google JWKS: %w", err)
	}
	return &Verifier{clientID: strings.TrimSpace(clientID), kf: kf}, nil
}

type claims struct {
	jwtlib.RegisteredClaims
	Email      string `json:"email"`
	GivenName  string `json:"given_name"`
	FamilyName string `json:"family_name"`
	Name       string `json:"name"`
	Picture    string `json:"picture"`
}

func (v *Verifier) Verify(ctx context.Context, idToken string) (domain.GoogleIDClaims, error) {
	if v.clientID == "" {
		return domain.GoogleIDClaims{}, errors.New("google client id not configured")
	}
	c := &claims{}
	parser := jwtlib.NewParser(
		jwtlib.WithValidMethods([]string{"RS256"}),
		jwtlib.WithExpirationRequired(),
		jwtlib.WithTimeFunc(func() time.Time { return time.Now() }),
	)
	token, err := parser.ParseWithClaims(idToken, c, v.kf.Keyfunc)
	if err != nil {
		return domain.GoogleIDClaims{}, fmt.Errorf("%w: %v", domain.ErrUnauthorized, err)
	}
	if !token.Valid {
		return domain.GoogleIDClaims{}, domain.ErrUnauthorized
	}
	iss := c.Issuer
	if iss != "https://accounts.google.com" && iss != "accounts.google.com" {
		return domain.GoogleIDClaims{}, domain.ErrUnauthorized
	}
	audOK := false
	for _, a := range c.Audience {
		if a == v.clientID {
			audOK = true
			break
		}
	}
	if !audOK {
		return domain.GoogleIDClaims{}, domain.ErrUnauthorized
	}
	if c.Subject == "" {
		return domain.GoogleIDClaims{}, errors.New("google id_token missing sub")
	}
	if strings.TrimSpace(c.Email) == "" {
		return domain.GoogleIDClaims{}, errors.New("google id_token missing email")
	}
	out := domain.GoogleIDClaims{
		Sub:        c.Subject,
		Email:      strings.TrimSpace(strings.ToLower(c.Email)),
		GivenName:  strings.TrimSpace(c.GivenName),
		FamilyName: strings.TrimSpace(c.FamilyName),
		FullName:   strings.TrimSpace(c.Name),
	}
	if c.Picture != "" {
		pic := c.Picture
		out.PictureURL = &pic
	}
	return out, nil
}
