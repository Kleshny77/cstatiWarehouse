package jwt

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestIssuer_IssueAndParse_Roundtrip(t *testing.T) {
	issuer := NewIssuer("test-secret-that-is-long-enough-for-signing", 15*time.Minute)
	userID := uuid.New()
	now := time.Now()

	token, exp, err := issuer.IssueAccessToken(userID, now)
	if err != nil {
		t.Fatalf("issue failed: %v", err)
	}
	if token == "" {
		t.Fatal("token must not be empty")
	}
	if !exp.After(now) {
		t.Fatal("expiration must be after issued_at")
	}

	parsedID, err := issuer.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	if parsedID != userID {
		t.Errorf("expected user id %s, got %s", userID, parsedID)
	}
}

func TestIssuer_Parse_WrongSecret(t *testing.T) {
	issuerA := NewIssuer("secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 15*time.Minute)
	issuerB := NewIssuer("secret-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", 15*time.Minute)

	token, _, err := issuerA.IssueAccessToken(uuid.New(), time.Now())
	if err != nil {
		t.Fatalf("issue failed: %v", err)
	}
	if _, err := issuerB.ParseAccessToken(token); err == nil {
		t.Error("parse with wrong secret must fail")
	}
}

func TestIssuer_Parse_Expired(t *testing.T) {
	issuer := NewIssuer("test-secret-that-is-long-enough-for-signing", -time.Minute)
	token, _, err := issuer.IssueAccessToken(uuid.New(), time.Now())
	if err != nil {
		t.Fatalf("issue failed: %v", err)
	}
	if _, err := issuer.ParseAccessToken(token); err == nil {
		t.Error("parse of expired token must fail")
	}
}

func TestRefreshGenerator_HashIsDeterministic(t *testing.T) {
	g := NewRefreshGenerator()
	plaintext, hash, err := g.Generate()
	if err != nil {
		t.Fatalf("generate failed: %v", err)
	}
	if g.Hash(plaintext) != hash {
		t.Error("Hash(plaintext) must equal hash returned from Generate")
	}
}
