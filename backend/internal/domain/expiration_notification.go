package domain

import (
	"time"

	"github.com/google/uuid"
)

type ExpirationLevel string

const (
	ExpirationLevelEarlyWarning ExpirationLevel = "early_warning"
	ExpirationLevelActionRequired ExpirationLevel = "action_required"
	ExpirationLevelCritical ExpirationLevel = "critical"
	ExpirationLevelExpired ExpirationLevel = "expired"
)

func (l ExpirationLevel) ThresholdDays() int {
	switch l {
	case ExpirationLevelEarlyWarning:
		return 7
	case ExpirationLevelActionRequired:
		return 3
	case ExpirationLevelCritical:
		return 1
	case ExpirationLevelExpired:
		return 0
	}
	return -1
}

func IsValidExpirationLevel(l ExpirationLevel) bool {
	switch l {
	case ExpirationLevelEarlyWarning,
		ExpirationLevelActionRequired,
		ExpirationLevelCritical,
		ExpirationLevelExpired:
		return true
	}
	return false
}

func AllExpirationLevels() []ExpirationLevel {
	return []ExpirationLevel{
		ExpirationLevelEarlyWarning,
		ExpirationLevelActionRequired,
		ExpirationLevelCritical,
		ExpirationLevelExpired,
	}
}

type DeliveryStatus string

const (
	DeliveryStatusSent    DeliveryStatus = "sent"
	DeliveryStatusFailed  DeliveryStatus = "failed"
	DeliveryStatusSnoozed DeliveryStatus = "snoozed"
)

type ExpirationNotification struct {
	ID             uuid.UUID
	ItemID         uuid.UUID
	OrganizationID uuid.UUID
	UserID         uuid.UUID
	Level          ExpirationLevel
	SentAt         time.Time
	DeliveryStatus DeliveryStatus
	SnoozeUntil    *time.Time
}

type UserNotificationPreferences struct {
	UserID                uuid.UUID
	EarlyWarningEnabled   bool
	ActionRequiredEnabled bool
	CriticalEnabled       bool
	ExpiredEnabled        bool
	QuietHoursStartMinute int
	QuietHoursEndMinute   int
	Timezone              string
	UpdatedAt             time.Time
}

func DefaultUserNotificationPreferences(userID uuid.UUID, now time.Time) UserNotificationPreferences {
	return UserNotificationPreferences{
		UserID:                userID,
		EarlyWarningEnabled:   true,
		ActionRequiredEnabled: true,
		CriticalEnabled:       true,
		ExpiredEnabled:        true,
		QuietHoursStartMinute: 22 * 60,
		QuietHoursEndMinute:   8 * 60,
		Timezone:              "Europe/Moscow",
		UpdatedAt:             now,
	}
}

func (p UserNotificationPreferences) IsLevelEnabled(l ExpirationLevel) bool {
	switch l {
	case ExpirationLevelEarlyWarning:
		return p.EarlyWarningEnabled
	case ExpirationLevelActionRequired:
		return p.ActionRequiredEnabled
	case ExpirationLevelCritical:
		return p.CriticalEnabled
	case ExpirationLevelExpired:
		return p.ExpiredEnabled
	}
	return false
}

func (p UserNotificationPreferences) IsInQuietHours(t time.Time, level ExpirationLevel) bool {
	if level == ExpirationLevelCritical {
		return false
	}
	loc, err := time.LoadLocation(p.Timezone)
	if err != nil || loc == nil {
		loc = time.UTC
	}
	local := t.In(loc)
	minute := local.Hour()*60 + local.Minute()
	start, end := p.QuietHoursStartMinute, p.QuietHoursEndMinute
	if start == end {
		return false
	}
	if start < end {
		return minute >= start && minute < end
	}
	return minute >= start || minute < end
}
