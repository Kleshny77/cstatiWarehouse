package invitecode

import (
	"strings"
	"testing"
)

func TestNewGenerator_DefaultLengthWhenZeroOrNegative(t *testing.T) {
	g := NewGenerator(0)
	if g.length != DefaultLength {
		t.Fatalf("expected length %d, got %d", DefaultLength, g.length)
	}
	g2 := NewGenerator(-3)
	if g2.length != DefaultLength {
		t.Fatalf("expected length %d, got %d", DefaultLength, g2.length)
	}
}

func TestGenerator_Generate_LengthAndAlphabet(t *testing.T) {
	g := NewGenerator(12)
	out, err := g.Generate()
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	if len(out) != 12 {
		t.Fatalf("expected len 12, got %d", len(out))
	}
	for _, r := range out {
		if !strings.ContainsRune(alphabet, r) {
			t.Fatalf("unexpected rune %q in %q", r, out)
		}
	}
}
