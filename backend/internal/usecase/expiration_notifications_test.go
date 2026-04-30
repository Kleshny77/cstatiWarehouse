package usecase

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func TestExpirationNotificationsUseCase_GetPreferences_unauthorized(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 4, 1, 12, 0, 0, 0, time.UTC))
	uc := NewExpirationNotificationsUseCase(&fakeExpNotifStore{prefs: map[uuid.UUID]*domain.UserNotificationPreferences{}}, nil, nil, clk)

	if _, err := uc.GetPreferences(context.Background(), uuid.Nil); !errors.Is(err, domain.ErrUnauthorized) {
		t.Fatalf("got %v", err)
	}
}

func TestExpirationNotificationsUseCase_GetPreferences_defaultWhenMissing(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 4, 1, 12, 0, 0, 0, time.UTC))
	uid := uuid.New()
	store := &fakeExpNotifStore{prefs: map[uuid.UUID]*domain.UserNotificationPreferences{}}
	uc := NewExpirationNotificationsUseCase(store, nil, nil, clk)

	p, err := uc.GetPreferences(context.Background(), uid)
	if err != nil {
		t.Fatal(err)
	}
	if p.UserID != uid {
		t.Fatalf("user id: %+v", p)
	}
}

func TestExpirationNotificationsUseCase_SnoozeItem_validation(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 4, 1, 12, 0, 0, 0, time.UTC))
	store := &fakeExpNotifStore{prefs: map[uuid.UUID]*domain.UserNotificationPreferences{}}
	uc := NewExpirationNotificationsUseCase(store, nil, nil, clk)
	ctx := context.Background()

	if err := uc.SnoozeItem(ctx, uuid.Nil, uuid.New(), time.Hour); !errors.Is(err, domain.ErrUnauthorized) {
		t.Fatalf("nil user: %v", err)
	}
	if err := uc.SnoozeItem(ctx, uuid.New(), uuid.New(), 0); err == nil {
		t.Fatal("zero duration")
	}
	if err := uc.SnoozeItem(ctx, uuid.New(), uuid.New(), 8*24*time.Hour); err == nil {
		t.Fatal("too long snooze")
	}
}

func TestExpirationNotificationsUseCase_UpdatePreferences_validation(t *testing.T) {
	clk := newFakeClock(time.Date(2026, 4, 1, 12, 0, 0, 0, time.UTC))
	uid := uuid.New()
	store := &fakeExpNotifStore{prefs: map[uuid.UUID]*domain.UserNotificationPreferences{}}
	uc := NewExpirationNotificationsUseCase(store, nil, nil, clk)
	ctx := context.Background()

	v := 2000
	if _, err := uc.UpdatePreferences(ctx, UpdatePreferencesInput{
		UserID:                uid,
		QuietHoursStartMinute: &v,
	}); err == nil {
		t.Fatal("bad quiet start")
	}

	tz := "Invalid/Zone"
	if _, err := uc.UpdatePreferences(ctx, UpdatePreferencesInput{
		UserID:   uid,
		Timezone: &tz,
	}); err == nil {
		t.Fatal("bad tz")
	}
}

func TestBuildNotificationText_pluralsRu(t *testing.T) {
	title, body := buildNotificationText(domain.ExpirationLevelEarlyWarning, "Молоко", 21)
	if !strings.Contains(title, "Скоро") {
		t.Fatal(title)
	}
	if !strings.Contains(body, "21") || !(strings.Contains(body, "день") || strings.Contains(body, "дня") || strings.Contains(body, "дней")) {
		t.Fatal(body)
	}
	title2, body2 := buildNotificationText(domain.ExpirationLevelExpired, "Сыр", -3)
	if !strings.Contains(title2, "истёк") {
		t.Fatal(title2)
	}
	if !strings.Contains(body2, "3") {
		t.Fatal(body2)
	}
}

// fakeExpNotifStore — заглушка для юнит-тестов настроек уведомлений.

type fakeExpNotifStore struct {
	mu    sync.Mutex
	prefs map[uuid.UUID]*domain.UserNotificationPreferences
}

func (s *fakeExpNotifStore) HasNotification(ctx context.Context, itemID uuid.UUID, level domain.ExpirationLevel, userID uuid.UUID) (bool, error) {
	return false, nil
}

func (s *fakeExpNotifStore) MarkSent(ctx context.Context, n *domain.ExpirationNotification) (bool, error) {
	return true, nil
}

func (s *fakeExpNotifStore) GetPreferences(ctx context.Context, userID uuid.UUID) (*domain.UserNotificationPreferences, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.prefs[userID]
	if !ok {
		return nil, domain.ErrNotFound
	}
	return p, nil
}

func (s *fakeExpNotifStore) UpsertPreferences(ctx context.Context, p *domain.UserNotificationPreferences) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.prefs[p.UserID] = p
	return nil
}

func (s *fakeExpNotifStore) ListRecentForUser(ctx context.Context, userID uuid.UUID, limit int) ([]domain.ExpirationNotification, error) {
	return nil, nil
}

func (s *fakeExpNotifStore) SnoozeForItem(ctx context.Context, itemID, userID uuid.UUID, until time.Time) error {
	return nil
}
