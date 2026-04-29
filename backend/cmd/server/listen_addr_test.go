package main

import "testing"

func TestNormalizeListenAddrForGoDualStack(t *testing.T) {
	t.Parallel()
	if got := normalizeListenAddrForGoDualStack("0.0.0.0:8080"); got != ":8080" {
		t.Fatalf("got %q want :8080", got)
	}
	if got := normalizeListenAddrForGoDualStack(":8080"); got != ":8080" {
		t.Fatalf("got %q want :8080", got)
	}
	if got := normalizeListenAddrForGoDualStack("127.0.0.1:8080"); got != "127.0.0.1:8080" {
		t.Fatalf("got %q", got)
	}
}
