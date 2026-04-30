package repo

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type ExpirationNotificationRepo struct {
	pool *pgxpool.Pool
}

func NewExpirationNotificationRepo(pool *pgxpool.Pool) *ExpirationNotificationRepo {
	return &ExpirationNotificationRepo{pool: pool}
}

func (r *ExpirationNotificationRepo) HasNotification(ctx context.Context, itemID uuid.UUID, level domain.ExpirationLevel, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM expiration_notifications
			WHERE item_id = $1 AND level = $2 AND user_id = $3
		)
	`, itemID, string(level), userID).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

func (r *ExpirationNotificationRepo) MarkSent(ctx context.Context, n *domain.ExpirationNotification) (bool, error) {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	tag, err := r.pool.Exec(ctx, `
		INSERT INTO expiration_notifications
			(id, item_id, organization_id, user_id, level, sent_at, delivery_status, snooze_until)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (item_id, level, user_id) DO NOTHING
	`, n.ID, n.ItemID, n.OrganizationID, n.UserID, string(n.Level), n.SentAt, string(n.DeliveryStatus), n.SnoozeUntil)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *ExpirationNotificationRepo) ListRecentForUser(ctx context.Context, userID uuid.UUID, limit int) ([]domain.ExpirationNotification, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, item_id, organization_id, user_id, level, sent_at, delivery_status, snooze_until
		FROM expiration_notifications
		WHERE user_id = $1
		ORDER BY sent_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]domain.ExpirationNotification, 0, limit)
	for rows.Next() {
		var n domain.ExpirationNotification
		var lvl, st string
		if err := rows.Scan(&n.ID, &n.ItemID, &n.OrganizationID, &n.UserID, &lvl, &n.SentAt, &st, &n.SnoozeUntil); err != nil {
			return nil, err
		}
		n.Level = domain.ExpirationLevel(lvl)
		n.DeliveryStatus = domain.DeliveryStatus(st)
		out = append(out, n)
	}
	return out, rows.Err()
}

func (r *ExpirationNotificationRepo) SnoozeForItem(ctx context.Context, itemID, userID uuid.UUID, until time.Time) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE expiration_notifications
		SET delivery_status = 'snoozed', snooze_until = $3
		WHERE item_id = $1 AND user_id = $2
	`, itemID, userID, until)
	return err
}

func (r *ExpirationNotificationRepo) GetPreferences(ctx context.Context, userID uuid.UUID) (*domain.UserNotificationPreferences, error) {
	var p domain.UserNotificationPreferences
	err := r.pool.QueryRow(ctx, `
		SELECT user_id, early_warning_enabled, action_required_enabled, critical_enabled, expired_enabled,
		       quiet_hours_start_minute, quiet_hours_end_minute, timezone, updated_at
		FROM user_notification_preferences
		WHERE user_id = $1
	`, userID).Scan(
		&p.UserID, &p.EarlyWarningEnabled, &p.ActionRequiredEnabled, &p.CriticalEnabled, &p.ExpiredEnabled,
		&p.QuietHoursStartMinute, &p.QuietHoursEndMinute, &p.Timezone, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *ExpirationNotificationRepo) UpsertPreferences(ctx context.Context, p *domain.UserNotificationPreferences) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO user_notification_preferences
			(user_id, early_warning_enabled, action_required_enabled, critical_enabled, expired_enabled,
			 quiet_hours_start_minute, quiet_hours_end_minute, timezone, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (user_id) DO UPDATE SET
			early_warning_enabled = EXCLUDED.early_warning_enabled,
			action_required_enabled = EXCLUDED.action_required_enabled,
			critical_enabled = EXCLUDED.critical_enabled,
			expired_enabled = EXCLUDED.expired_enabled,
			quiet_hours_start_minute = EXCLUDED.quiet_hours_start_minute,
			quiet_hours_end_minute = EXCLUDED.quiet_hours_end_minute,
			timezone = EXCLUDED.timezone,
			updated_at = EXCLUDED.updated_at
	`, p.UserID, p.EarlyWarningEnabled, p.ActionRequiredEnabled, p.CriticalEnabled, p.ExpiredEnabled,
		p.QuietHoursStartMinute, p.QuietHoursEndMinute, p.Timezone, p.UpdatedAt)
	return err
}

func (r *ExpirationNotificationRepo) ListItemsExpiringWithin(ctx context.Context, now time.Time, horizonDays int) ([]ExpirationCandidate, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT i.id, i.organization_id, i.held_by_user_id, i.name, i.expiration_date, i.image_url
		FROM items i
		WHERE i.deleted_at IS NULL
		  AND i.archived_at IS NULL
		  AND i.expiration_date IS NOT NULL
		  AND i.expiration_date <= ($1::timestamptz + make_interval(days => $2::int))
	`, now, horizonDays)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]ExpirationCandidate, 0, 64)
	for rows.Next() {
		var c ExpirationCandidate
		if err := rows.Scan(&c.ItemID, &c.OrganizationID, &c.HeldByUserID, &c.ItemName, &c.ExpirationDate, &c.ImageURL); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

type ExpirationCandidate struct {
	ItemID         uuid.UUID
	OrganizationID uuid.UUID
	HeldByUserID   uuid.UUID
	ItemName       string
	ExpirationDate time.Time
	ImageURL       *string
}
