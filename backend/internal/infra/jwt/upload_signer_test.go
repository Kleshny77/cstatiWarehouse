package jwt_test

import (
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
)

func TestUploadURLSignerRoundTrip(t *testing.T) {
	t.Parallel()
	s := jwt.NewUploadURLSigner(strings.Repeat("a", 32), time.Hour)
	name := "550e8400-e29b-41d4-a716-446655440000.jpg"
	tok, err := s.Sign(name, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	got, err := s.Verify(tok)
	if err != nil {
		t.Fatal(err)
	}
	if got != name {
		t.Fatalf("got %q want %q", got, name)
	}
}

func TestUploadURLSignerWrongSecret(t *testing.T) {
	t.Parallel()
	a := jwt.NewUploadURLSigner(strings.Repeat("a", 32), time.Hour)
	b := jwt.NewUploadURLSigner(strings.Repeat("b", 32), time.Hour)
	tok, err := a.Sign("550e8400-e29b-41d4-a716-446655440000.jpg", time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := b.Verify(tok); err == nil {
		t.Fatal("expected verify failure")
	}
}

func TestUploadURLSigner_NotAccessToken(t *testing.T) {
	t.Parallel()
	upload := jwt.NewUploadURLSigner(strings.Repeat("x", 32), time.Hour)
	accessIssuer := jwt.NewIssuer(strings.Repeat("x", 32), time.Minute)
	id := uuid.MustParse("550e8400-e29b-41d4-a716-446655440000")
	tok, _, err := accessIssuer.IssueAccessToken(id, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := upload.Verify(tok); err == nil {
		t.Fatal("access token must not verify as upload token")
	}
}
