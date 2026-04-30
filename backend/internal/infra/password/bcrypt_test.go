package password

import (
	"errors"
	"testing"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func TestBcryptHasher_HashVerify(t *testing.T) {
	h := NewBcryptHasher(4)

	hash, err := h.Hash("supersecret")
	if err != nil {
		t.Fatalf("hash failed: %v", err)
	}
	if hash == "" || hash == "supersecret" {
		t.Error("hash must be non-empty and not equal to password")
	}

	if err := h.Verify(hash, "supersecret"); err != nil {
		t.Errorf("correct password must verify, got %v", err)
	}
	if err := h.Verify(hash, "wrong"); !errors.Is(err, domain.ErrInvalidCreds) {
		t.Errorf("wrong password must return ErrInvalidCreds, got %v", err)
	}
}
