package repo

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DevicePushTokenRepo struct {
	pool *pgxpool.Pool
}

func NewDevicePushTokenRepo(pool *pgxpool.Pool) *DevicePushTokenRepo {
	return &DevicePushTokenRepo{pool: pool}
}

func (r *DevicePushTokenRepo) UpsertAPNs(ctx context.Context, userID uuid.UUID, apnsToken string, now time.Time) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO device_push_tokens (user_id, apns_token, updated_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE SET apns_token = EXCLUDED.apns_token, updated_at = EXCLUDED.updated_at
	`, userID, apnsToken, now)
	return err
}
