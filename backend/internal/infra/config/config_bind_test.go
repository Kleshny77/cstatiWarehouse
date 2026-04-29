package config

import "testing"

func TestIsLoopbackOnlyHTTPAddr(t *testing.T) {
	t.Parallel()
	tests := []struct {
		addr string
		want bool
	}{
		{":8080", false},
		{"::8080", false}, // invalid for Go really, but don't mis-detect
		{"0.0.0.0:8080", false},
		{"[::]:8080", false},
		{"127.0.0.1:8080", true},
		{"[::1]:8080", true},
		{"localhost:8080", true},
		{"", false},
	}
	for _, tc := range tests {
		got := isLoopbackOnlyHTTPAddr(tc.addr)
		if got != tc.want {
			t.Fatalf("%q: got %v want %v", tc.addr, got, tc.want)
		}
	}
}

func TestConfigBindLANWarnings(t *testing.T) {
	t.Parallel()
	w := (Config{HTTPAddr: "127.0.0.1:8080"}).BindLANWarnings()
	if len(w) != 1 {
		t.Fatalf("expected 1 warning, got %d", len(w))
	}
	if len((Config{HTTPAddr: ":8080"}).BindLANWarnings()) != 0 {
		t.Fatal("expected no warnings for :8080")
	}
}
