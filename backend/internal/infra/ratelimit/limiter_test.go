package ratelimit

import (
	"testing"
	"time"
)

func TestPerIPLimiter_BurstThenThrottle(t *testing.T) {
	lim := NewPerIPLimiter(time.Minute, 2, 128)
	ip := "203.0.113.10"

	if !lim.Allow(ip) || !lim.Allow(ip) {
		t.Fatal("expected two immediate allows from burst")
	}
	if lim.Allow(ip) {
		t.Fatal("expected third request denied until refill")
	}
}

func TestPerIPLimiter_MaxIPsResetsTable(t *testing.T) {
	lim := NewPerIPLimiter(time.Minute, 1, 2)

	if !lim.Allow("10.0.0.1") {
		t.Fatal("first ip")
	}
	if !lim.Allow("10.0.0.2") {
		t.Fatal("second ip")
	}
	if !lim.Allow("10.0.0.3") {
		t.Fatal("third ip should reset map and still allow once")
	}
	if lim.Count() > 2 {
		t.Fatalf("unexpected bucket count: %d", lim.Count())
	}
}

func TestPerIPLimiter_ResetClears(t *testing.T) {
	lim := NewPerIPLimiter(time.Minute, 3, 100)
	_ = lim.Allow("198.51.100.1")
	lim.Reset()
	if lim.Count() != 0 {
		t.Fatalf("expected 0 keys after reset, got %d", lim.Count())
	}
}
