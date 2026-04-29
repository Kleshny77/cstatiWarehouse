package jwt

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"time"

	jwtlib "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var ErrInvalidToken = errors.New("invalid access token")

type Issuer struct {
	secret []byte
	ttl    time.Duration
}

func NewIssuer(secret string, ttl time.Duration) *Issuer {
	return &Issuer{secret: []byte(secret), ttl: ttl}
}

func (i *Issuer) IssueAccessToken(userID uuid.UUID, issuedAt time.Time) (string, time.Time, error) {
	exp := issuedAt.Add(i.ttl)
	claims := jwtlib.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwtlib.NewNumericDate(issuedAt),
		NotBefore: jwtlib.NewNumericDate(issuedAt),
		ExpiresAt: jwtlib.NewNumericDate(exp),
	}
	token := jwtlib.NewWithClaims(jwtlib.SigningMethodHS256, claims)
	signed, err := token.SignedString(i.secret)
	if err != nil {
		return "", time.Time{}, err
	}
	return signed, exp, nil
}

func (i *Issuer) ParseAccessToken(tokenStr string) (uuid.UUID, error) {
	parser := jwtlib.NewParser(jwtlib.WithValidMethods([]string{jwtlib.SigningMethodHS256.Alg()}))

	token, err := parser.ParseWithClaims(tokenStr, &jwtlib.RegisteredClaims{}, func(t *jwtlib.Token) (interface{}, error) {
		return i.secret, nil
	})
	if err != nil {
		return uuid.Nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*jwtlib.RegisteredClaims)
	if !ok || !token.Valid {
		return uuid.Nil, ErrInvalidToken
	}
	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, ErrInvalidToken
	}
	return userID, nil
}

type RefreshGenerator struct {
	size int
}

func NewRefreshGenerator() *RefreshGenerator {
	return &RefreshGenerator{size: 32}
}

func (g *RefreshGenerator) Generate() (string, string, error) {
	buf := make([]byte, g.size)
	if _, err := rand.Read(buf); err != nil {
		return "", "", err
	}
	plaintext := base64.RawURLEncoding.EncodeToString(buf)
	return plaintext, g.Hash(plaintext), nil
}

func (g *RefreshGenerator) Hash(plaintext string) string {
	sum := sha256.Sum256([]byte(plaintext))
	return hex.EncodeToString(sum[:])
}
