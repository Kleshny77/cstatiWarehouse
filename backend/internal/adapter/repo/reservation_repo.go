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

type ReservationRepo struct {
	pool *pgxpool.Pool
}

func NewReservationRepo(pool *pgxpool.Pool) *ReservationRepo {
	return &ReservationRepo{pool: pool}
}

const reservationColumns = `id, item_id, organization_id, quantity, event_id,
	reserved_by_user_id, reserved_at, expires_at, status,
	fulfilled_at, fulfilled_by_user_id,
	cancelled_at, cancelled_by_user_id, cancellation_reason,
	notes, created_at, updated_at`

func (r *ReservationRepo) Create(ctx context.Context, reservation *domain.ItemReservation) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var itemQuantity int
	var itemStatus string
	if err := tx.QueryRow(ctx, `
		SELECT quantity, status FROM items WHERE id = $1 FOR UPDATE
	`, reservation.ItemID).Scan(&itemQuantity, &itemStatus); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return err
	}
	if itemStatus != "in_stock" {
		return domain.NewValidationError("item is archived")
	}

	var activeReserved int64
	if err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(quantity), 0)
		FROM item_reservations
		WHERE item_id = $1 AND status = 'active'
	`, reservation.ItemID).Scan(&activeReserved); err != nil {
		return err
	}
	available := int64(itemQuantity) - activeReserved
	if int64(reservation.Quantity) > available {
		return domain.ErrConflict
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO item_reservations
			(id, item_id, organization_id, quantity, event_id,
			 reserved_by_user_id, reserved_at, expires_at, status,
			 notes, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
	`,
		reservation.ID, reservation.ItemID, reservation.OrganizationID,
		reservation.Quantity, reservation.EventID,
		reservation.ReservedByUserID, reservation.ReservedAt, reservation.ExpiresAt, string(reservation.Status),
		reservation.Notes, reservation.CreatedAt, reservation.UpdatedAt,
	); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *ReservationRepo) Update(ctx context.Context, reservation *domain.ItemReservation) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE item_reservations SET
			quantity = $2,
			event_id = $3,
			expires_at = $4,
			status = $5,
			fulfilled_at = $6,
			fulfilled_by_user_id = $7,
			cancelled_at = $8,
			cancelled_by_user_id = $9,
			cancellation_reason = $10,
			notes = $11,
			updated_at = $12
		WHERE id = $1
	`,
		reservation.ID,
		reservation.Quantity, reservation.EventID,
		reservation.ExpiresAt, string(reservation.Status),
		reservation.FulfilledAt, reservation.FulfilledByUserID,
		reservation.CancelledAt, reservation.CancelledByUserID, reservation.CancellationReason,
		reservation.Notes, reservation.UpdatedAt,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *ReservationRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.ItemReservation, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+reservationColumns+` FROM item_reservations WHERE id = $1`, id)
	return scanReservation(row)
}

func (r *ReservationRepo) ListByItem(
	ctx context.Context,
	itemID uuid.UUID,
	status *domain.ReservationStatus,
) ([]domain.ItemReservation, error) {
	if status != nil {
		rows, err := r.pool.Query(ctx, `
			SELECT `+reservationColumns+`
			FROM item_reservations
			WHERE item_id = $1 AND status = $2
			ORDER BY created_at DESC
		`, itemID, string(*status))
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		return collectReservations(rows)
	}
	rows, err := r.pool.Query(ctx, `
		SELECT `+reservationColumns+`
		FROM item_reservations
		WHERE item_id = $1
		ORDER BY created_at DESC
	`, itemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return collectReservations(rows)
}

func (r *ReservationRepo) ListByOrganization(
	ctx context.Context,
	orgID uuid.UUID,
	status *domain.ReservationStatus,
) ([]domain.ItemReservation, error) {
	if status != nil {
		rows, err := r.pool.Query(ctx, `
			SELECT `+reservationColumns+`
			FROM item_reservations
			WHERE organization_id = $1 AND status = $2
			ORDER BY created_at DESC
		`, orgID, string(*status))
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		return collectReservations(rows)
	}
	rows, err := r.pool.Query(ctx, `
		SELECT `+reservationColumns+`
		FROM item_reservations
		WHERE organization_id = $1
		ORDER BY created_at DESC
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return collectReservations(rows)
}

func (r *ReservationRepo) GetActiveTotalReservedForItem(ctx context.Context, itemID uuid.UUID) (int, error) {
	var total int64
	if err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(quantity), 0)
		FROM item_reservations
		WHERE item_id = $1 AND status = 'active'
	`, itemID).Scan(&total); err != nil {
		return 0, err
	}
	return int(total), nil
}

func (r *ReservationRepo) GetActiveTotalsForItems(
	ctx context.Context,
	itemIDs []uuid.UUID,
) (map[uuid.UUID]int, error) {
	out := make(map[uuid.UUID]int, len(itemIDs))
	if len(itemIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT item_id, COALESCE(SUM(quantity), 0)
		FROM item_reservations
		WHERE status = 'active' AND item_id = ANY($1)
		GROUP BY item_id
	`, itemIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id uuid.UUID
		var total int64
		if err := rows.Scan(&id, &total); err != nil {
			return nil, err
		}
		out[id] = int(total)
	}
	return out, rows.Err()
}

func (r *ReservationRepo) FindExpired(ctx context.Context, now time.Time) ([]domain.ItemReservation, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+reservationColumns+`
		FROM item_reservations
		WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= $1
		ORDER BY expires_at ASC
		LIMIT 500
	`, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return collectReservations(rows)
}

func collectReservations(rows pgx.Rows) ([]domain.ItemReservation, error) {
	var out []domain.ItemReservation
	for rows.Next() {
		r, err := scanReservation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *r)
	}
	return out, rows.Err()
}

func scanReservation(row pgx.Row) (*domain.ItemReservation, error) {
	var r domain.ItemReservation
	var statusStr string
	if err := row.Scan(
		&r.ID, &r.ItemID, &r.OrganizationID, &r.Quantity, &r.EventID,
		&r.ReservedByUserID, &r.ReservedAt, &r.ExpiresAt, &statusStr,
		&r.FulfilledAt, &r.FulfilledByUserID,
		&r.CancelledAt, &r.CancelledByUserID, &r.CancellationReason,
		&r.Notes, &r.CreatedAt, &r.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	r.Status = domain.ReservationStatus(statusStr)
	return &r, nil
}
