package jwt

import (
	"errors"
	"strings"
	"time"

	jwtlib "github.com/golang-jwt/jwt/v5"
)

const uploadTokenTyp = "upload"

var ErrInvalidUploadToken = errors.New("invalid upload token")

// UploadURLSigner выпускает короткоживущие JWT для GET /uploads/{file}?token=...
type UploadURLSigner struct {
	secret []byte
	ttl    time.Duration
}

func NewUploadURLSigner(secret string, ttl time.Duration) *UploadURLSigner {
	return &UploadURLSigner{secret: []byte(secret), ttl: ttl}
}

func (s *UploadURLSigner) Sign(filename string, now time.Time) (string, error) {
	filename = strings.TrimSpace(filename)
	if filename == "" {
		return "", errors.New("empty filename")
	}
	exp := now.Add(s.ttl)
	claims := jwtlib.MapClaims{
		"typ": uploadTokenTyp,
		"sub": filename,
		"exp": float64(exp.Unix()),
		"iat": float64(now.Unix()),
	}
	t := jwtlib.NewWithClaims(jwtlib.SigningMethodHS256, claims)
	return t.SignedString(s.secret)
}

// Verify возвращает имя файла из токена или ошибку.
func (s *UploadURLSigner) Verify(tokenStr string) (filename string, err error) {
	parser := jwtlib.NewParser(jwtlib.WithValidMethods([]string{jwtlib.SigningMethodHS256.Alg()}))
	token, err := parser.ParseWithClaims(tokenStr, &jwtlib.MapClaims{}, func(t *jwtlib.Token) (interface{}, error) {
		return s.secret, nil
	})
	if err != nil || !token.Valid {
		return "", ErrInvalidUploadToken
	}
	claims, ok := token.Claims.(*jwtlib.MapClaims)
	if !ok {
		return "", ErrInvalidUploadToken
	}
	if typ, _ := (*claims)["typ"].(string); typ != uploadTokenTyp {
		return "", ErrInvalidUploadToken
	}
	sub, _ := (*claims)["sub"].(string)
	sub = strings.TrimSpace(sub)
	if sub == "" {
		return "", ErrInvalidUploadToken
	}
	return sub, nil
}
