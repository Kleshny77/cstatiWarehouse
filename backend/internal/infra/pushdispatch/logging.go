// Package pushdispatch contains push notification dispatchers.
//
// На текущем этапе APNs/FCM не подключены — используется LoggingDispatcher,
// который пишет каждый push в structured-лог. Это позволяет:
//   - запускать всю цепочку end-to-end в dev/integration тестах;
//   - проверять, что воркер собирает корректные payloads;
//   - сохранять API совместимость с будущей APNsDispatcher.
package pushdispatch

import (
	"context"
	"log/slog"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type LoggingDispatcher struct {
	logger *slog.Logger
}

func NewLoggingDispatcher(logger *slog.Logger) *LoggingDispatcher {
	if logger == nil {
		logger = slog.Default()
	}
	return &LoggingDispatcher{logger: logger}
}

func (d *LoggingDispatcher) Dispatch(ctx context.Context, p usecase.PushNotificationPayload) error {
	d.logger.InfoContext(ctx, "expiration push dispatch (stub)",
		"user_id", p.UserID.String(),
		"item_id", p.ItemID.String(),
		"organization_id", p.OrganizationID.String(),
		"level", string(p.Level),
		"days_until", p.DaysUntil,
		"category", p.CategoryID,
		"time_sensitive", p.TimeSensitive,
		"title", p.Title,
		"body", p.Body,
	)
	return nil
}
