//
// event_repo.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package repo

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type EventRepo struct {
	pool *pgxpool.Pool
}

func NewEventRepo(pool *pgxpool.Pool) *EventRepo {
	return &EventRepo{pool: pool}
}

const eventColumns = "id, organization_id, created_by, name, description, starts_at, created_at, updated_at"

func (r *EventRepo) Create(ctx context.Context, e *domain.Event) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO events (`+eventColumns+`)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, e.ID, e.OrganizationID, e.CreatedByID, e.Name, e.Description, e.StartsAt, e.CreatedAt, e.UpdatedAt)
	return err
}

func (r *EventRepo) Update(ctx context.Context, e *domain.Event) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE events SET name = $2, description = $3, starts_at = $4, updated_at = $5
		WHERE id = $1
	`, e.ID, e.Name, e.Description, e.StartsAt, e.UpdatedAt)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *EventRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Event, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+eventColumns+` FROM events WHERE id = $1`, id)
	return scanEvent(row)
}

func (r *EventRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Event, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+eventColumns+` FROM events
		WHERE organization_id = $1
		ORDER BY starts_at DESC NULLS LAST, created_at DESC
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Event
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *e)
	}
	return out, rows.Err()
}

func (r *EventRepo) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM events WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanEvent(row rowScanner) (*domain.Event, error) {
	var e domain.Event
	err := row.Scan(&e.ID, &e.OrganizationID, &e.CreatedByID, &e.Name, &e.Description, &e.StartsAt, &e.CreatedAt, &e.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &e, nil
}
