package usecase

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type ExpirationNotificationDispatcher interface {
	Dispatch(ctx context.Context, payload PushNotificationPayload) error
}

type PushNotificationPayload struct {
	UserID         uuid.UUID
	ItemID         uuid.UUID
	OrganizationID uuid.UUID
	Level          domain.ExpirationLevel
	ItemName       string
	DaysUntil      int
	ExpirationDate time.Time
	ImageURL       *string
	CategoryID string
	TimeSensitive bool
	Title string
	Body  string
}

type ExpirationCandidateProvider interface {
	ListItemsExpiringWithin(ctx context.Context, now time.Time, horizonDays int) ([]ExpirationCandidate, error)
}

type ExpirationCandidate struct {
	ItemID         uuid.UUID
	OrganizationID uuid.UUID
	HeldByUserID   uuid.UUID
	ItemName       string
	ExpirationDate time.Time
	ImageURL       *string
}

type ExpirationNotificationStore interface {
	HasNotification(ctx context.Context, itemID uuid.UUID, level domain.ExpirationLevel, userID uuid.UUID) (bool, error)
	MarkSent(ctx context.Context, n *domain.ExpirationNotification) (bool, error)
	GetPreferences(ctx context.Context, userID uuid.UUID) (*domain.UserNotificationPreferences, error)
	UpsertPreferences(ctx context.Context, p *domain.UserNotificationPreferences) error
	ListRecentForUser(ctx context.Context, userID uuid.UUID, limit int) ([]domain.ExpirationNotification, error)
	SnoozeForItem(ctx context.Context, itemID, userID uuid.UUID, until time.Time) error
}

type ExpirationNotificationsUseCase struct {
	store      ExpirationNotificationStore
	candidates ExpirationCandidateProvider
	dispatcher ExpirationNotificationDispatcher
	clock      Clock
}

func NewExpirationNotificationsUseCase(
	store ExpirationNotificationStore,
	candidates ExpirationCandidateProvider,
	dispatcher ExpirationNotificationDispatcher,
	clock Clock,
) *ExpirationNotificationsUseCase {
	return &ExpirationNotificationsUseCase{
		store:      store,
		candidates: candidates,
		dispatcher: dispatcher,
		clock:      clock,
	}
}

func (uc *ExpirationNotificationsUseCase) GetPreferences(ctx context.Context, userID uuid.UUID) (domain.UserNotificationPreferences, error) {
	if userID == uuid.Nil {
		return domain.UserNotificationPreferences{}, domain.ErrUnauthorized
	}
	p, err := uc.store.GetPreferences(ctx, userID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return domain.DefaultUserNotificationPreferences(userID, uc.clock.Now()), nil
		}
		return domain.UserNotificationPreferences{}, err
	}
	return *p, nil
}

type UpdatePreferencesInput struct {
	UserID                uuid.UUID
	EarlyWarningEnabled   *bool
	ActionRequiredEnabled *bool
	CriticalEnabled       *bool
	ExpiredEnabled        *bool
	QuietHoursStartMinute *int
	QuietHoursEndMinute   *int
	Timezone              *string
}

func (uc *ExpirationNotificationsUseCase) UpdatePreferences(ctx context.Context, in UpdatePreferencesInput) (domain.UserNotificationPreferences, error) {
	if in.UserID == uuid.Nil {
		return domain.UserNotificationPreferences{}, domain.ErrUnauthorized
	}
	current, err := uc.GetPreferences(ctx, in.UserID)
	if err != nil {
		return domain.UserNotificationPreferences{}, err
	}
	if in.EarlyWarningEnabled != nil {
		current.EarlyWarningEnabled = *in.EarlyWarningEnabled
	}
	if in.ActionRequiredEnabled != nil {
		current.ActionRequiredEnabled = *in.ActionRequiredEnabled
	}
	if in.CriticalEnabled != nil {
		current.CriticalEnabled = *in.CriticalEnabled
	}
	if in.ExpiredEnabled != nil {
		current.ExpiredEnabled = *in.ExpiredEnabled
	}
	if in.QuietHoursStartMinute != nil {
		v := *in.QuietHoursStartMinute
		if v < 0 || v > 1439 {
			return domain.UserNotificationPreferences{}, domain.NewValidationError("quiet_hours_start_minute out of range")
		}
		current.QuietHoursStartMinute = v
	}
	if in.QuietHoursEndMinute != nil {
		v := *in.QuietHoursEndMinute
		if v < 0 || v > 1439 {
			return domain.UserNotificationPreferences{}, domain.NewValidationError("quiet_hours_end_minute out of range")
		}
		current.QuietHoursEndMinute = v
	}
	if in.Timezone != nil {
		if _, err := time.LoadLocation(*in.Timezone); err != nil {
			return domain.UserNotificationPreferences{}, domain.NewValidationError("invalid timezone")
		}
		current.Timezone = *in.Timezone
	}
	current.UpdatedAt = uc.clock.Now()
	if err := uc.store.UpsertPreferences(ctx, &current); err != nil {
		return domain.UserNotificationPreferences{}, err
	}
	return current, nil
}

func (uc *ExpirationNotificationsUseCase) SnoozeItem(ctx context.Context, userID, itemID uuid.UUID, duration time.Duration) error {
	if userID == uuid.Nil {
		return domain.ErrUnauthorized
	}
	if duration <= 0 || duration > 7*24*time.Hour {
		return domain.NewValidationError("invalid snooze duration")
	}
	until := uc.clock.Now().Add(duration)
	return uc.store.SnoozeForItem(ctx, itemID, userID, until)
}

func (uc *ExpirationNotificationsUseCase) ListRecent(ctx context.Context, userID uuid.UUID, limit int) ([]domain.ExpirationNotification, error) {
	if userID == uuid.Nil {
		return nil, domain.ErrUnauthorized
	}
	return uc.store.ListRecentForUser(ctx, userID, limit)
}

type TickResult struct {
	Scanned   int
	Sent      int
	Skipped   int
	Failed    int
	StartedAt time.Time
	Duration  time.Duration
}

func (uc *ExpirationNotificationsUseCase) Tick(ctx context.Context) (TickResult, error) {
	now := uc.clock.Now()
	res := TickResult{StartedAt: now}
	candidates, err := uc.candidates.ListItemsExpiringWithin(ctx, now, 7)
	if err != nil {
		return res, err
	}
	res.Scanned = len(candidates)

	prefsCache := make(map[uuid.UUID]domain.UserNotificationPreferences, 16)

	for _, c := range candidates {
		if c.HeldByUserID == uuid.Nil {
			res.Skipped++
			continue
		}
		daysUntil := daysBetween(now, c.ExpirationDate)
		level := levelForDaysUntil(daysUntil)
		if level == "" {
			res.Skipped++
			continue
		}

		prefs, ok := prefsCache[c.HeldByUserID]
		if !ok {
			loaded, err := uc.store.GetPreferences(ctx, c.HeldByUserID)
			if err != nil {
				if errors.Is(err, domain.ErrNotFound) {
					prefs = domain.DefaultUserNotificationPreferences(c.HeldByUserID, now)
				} else {
					res.Failed++
					continue
				}
			} else {
				prefs = *loaded
			}
			prefsCache[c.HeldByUserID] = prefs
		}

		if !prefs.IsLevelEnabled(level) {
			res.Skipped++
			continue
		}
		if prefs.IsInQuietHours(now, level) {
			res.Skipped++
			continue
		}

		exists, err := uc.store.HasNotification(ctx, c.ItemID, level, c.HeldByUserID)
		if err != nil {
			res.Failed++
			continue
		}
		if exists {
			res.Skipped++
			continue
		}

		title, body := buildNotificationText(level, c.ItemName, daysUntil)
		payload := PushNotificationPayload{
			UserID:         c.HeldByUserID,
			ItemID:         c.ItemID,
			OrganizationID: c.OrganizationID,
			Level:          level,
			ItemName:       c.ItemName,
			DaysUntil:      daysUntil,
			ExpirationDate: c.ExpirationDate,
			ImageURL:       c.ImageURL,
			CategoryID:     "EXPIRATION_ACTION",
			TimeSensitive:  level == domain.ExpirationLevelCritical,
			Title:          title,
			Body:           body,
		}

		inserted, err := uc.store.MarkSent(ctx, &domain.ExpirationNotification{
			ItemID:         c.ItemID,
			OrganizationID: c.OrganizationID,
			UserID:         c.HeldByUserID,
			Level:          level,
			SentAt:         now,
			DeliveryStatus: domain.DeliveryStatusSent,
		})
		if err != nil {
			res.Failed++
			continue
		}
		if !inserted {
			res.Skipped++
			continue
		}
		if uc.dispatcher != nil {
			if err := uc.dispatcher.Dispatch(ctx, payload); err != nil {
				res.Failed++
				continue
			}
		}
		res.Sent++
	}

	res.Duration = uc.clock.Now().Sub(now)
	return res, nil
}

func daysBetween(from, to time.Time) int {
	d := to.Sub(from)
	return int(d / (24 * time.Hour))
}

func levelForDaysUntil(days int) domain.ExpirationLevel {
	switch {
	case days <= 0:
		return domain.ExpirationLevelExpired
	case days <= 1:
		return domain.ExpirationLevelCritical
	case days <= 3:
		return domain.ExpirationLevelActionRequired
	case days <= 7:
		return domain.ExpirationLevelEarlyWarning
	}
	return ""
}

func buildNotificationText(level domain.ExpirationLevel, itemName string, daysUntil int) (string, string) {
	switch level {
	case domain.ExpirationLevelEarlyWarning:
		return "Скоро истекает срок годности",
			itemName + " — осталось " + plural(daysUntil, "день", "дня", "дней") + ". Стоит запланировать использование."
	case domain.ExpirationLevelActionRequired:
		return "Срочно: запланируйте использование",
			itemName + " — осталось " + plural(daysUntil, "день", "дня", "дней") + ". Используйте или переместите в нужное место."
	case domain.ExpirationLevelCritical:
		return "Критично: завтра истекает",
			itemName + " истекает завтра. Используйте сегодня, иначе будет утилизирован."
	case domain.ExpirationLevelExpired:
		return "Срок годности истёк",
			itemName + " истёк " + plural(-daysUntil, "день", "дня", "дней") + " назад. Архивируйте позицию."
	}
	return itemName, ""
}

func plural(n int, one, few, many string) string {
	if n < 0 {
		n = -n
	}
	mod10 := n % 10
	mod100 := n % 100
	switch {
	case mod10 == 1 && mod100 != 11:
		return itoa(n) + " " + one
	case mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14):
		return itoa(n) + " " + few
	default:
		return itoa(n) + " " + many
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
