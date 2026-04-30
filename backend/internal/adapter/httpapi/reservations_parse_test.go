package httpapi

import (
	"testing"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func TestParseReservationStatus(t *testing.T) {
	t.Parallel()
	got, err := parseReservationStatus("")
	if err != nil || got != nil {
		t.Fatalf("empty: got %v err=%v", got, err)
	}
	got, err = parseReservationStatus("active")
	if err != nil || got == nil || *got != domain.ReservationStatusActive {
		t.Fatalf("active: %v err=%v", got, err)
	}
	_, err = parseReservationStatus("nope")
	if err == nil {
		t.Fatal("expected error")
	}
}
