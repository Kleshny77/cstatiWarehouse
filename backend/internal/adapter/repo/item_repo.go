package repo

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ItemRepo struct {
	pool *pgxpool.Pool
}

func NewItemRepo(pool *pgxpool.Pool) *ItemRepo {
	return &ItemRepo{pool: pool}
}

const itemColumns = `id, owner_id, name, description, category_name, quantity, status, archive_reason, archived_at, expiration_date, image_url, created_at, updated_at`

func (r *ItemRepo) Create(ctx context.Context, item *domain.Item) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO items (id, owner_id, name, description, category_name, quantity, status, archive_reason, archived_at, expiration_date, image_url, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
	`,
		item.ID, item.OwnerID, item.Name, item.Description, item.CategoryName, item.Quantity,
		string(item.Status), archiveReasonToDB(item.ArchiveReason), item.ArchivedAt,
		item.ExpirationDate, item.ImageURL, item.CreatedAt, item.UpdatedAt,
	)
	return err
}

func (r *ItemRepo) Update(ctx context.Context, item *domain.Item) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE items SET
			name = $2, description = $3, category_name = $4, quantity = $5,
			status = $6, archive_reason = $7, archived_at = $8,
			expiration_date = $9, image_url = $10, updated_at = $11
		WHERE id = $1
	`,
		item.ID, item.Name, item.Description, item.CategoryName, item.Quantity,
		string(item.Status), archiveReasonToDB(item.ArchiveReason), item.ArchivedAt,
		item.ExpirationDate, item.ImageURL, item.UpdatedAt,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *ItemRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Item, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+itemColumns+` FROM items WHERE id = $1`, id)
	return scanItem(row)
}

func (r *ItemRepo) ListByOwner(ctx context.Context, ownerID uuid.UUID, filter usecase.ItemFilter) ([]domain.Item, error) {
	query := `SELECT ` + itemColumns + ` FROM items WHERE owner_id = $1`
	args := []any{ownerID}
	if filter.Status != nil {
		query += ` AND status = $2`
		args = append(args, string(*filter.Status))
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Item
	for rows.Next() {
		item, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}

func (r *ItemRepo) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM items WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// RecordArchiveEvent атомарно обновляет item (quantity/status/archive_*) и вставляет событие.
func (r *ItemRepo) RecordArchiveEvent(ctx context.Context, item *domain.Item, event *domain.ArchiveEvent) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	tag, err := tx.Exec(ctx, `
		UPDATE items SET
			quantity = $2,
			status = $3,
			archive_reason = $4,
			archived_at = $5,
			updated_at = $6
		WHERE id = $1
	`,
		item.ID, item.Quantity, string(item.Status),
		archiveReasonToDB(item.ArchiveReason), item.ArchivedAt, item.UpdatedAt,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO item_archive_events (id, item_id, owner_id, quantity, reason, reason_detail, archived_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`,
		event.ID, event.ItemID, event.OwnerID, event.Quantity,
		string(event.Reason), event.ReasonDetail, event.ArchivedAt,
	); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// ListArchiveEvents возвращает все события списания пользователя, начиная с самых свежих.
func (r *ItemRepo) ListArchiveEvents(ctx context.Context, ownerID uuid.UUID) ([]domain.ArchiveEvent, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, item_id, owner_id, quantity, reason, reason_detail, archived_at
		FROM item_archive_events
		WHERE owner_id = $1
		ORDER BY archived_at DESC
	`, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.ArchiveEvent
	for rows.Next() {
		var e domain.ArchiveEvent
		var reason string
		if err := rows.Scan(&e.ID, &e.ItemID, &e.OwnerID, &e.Quantity, &reason, &e.ReasonDetail, &e.ArchivedAt); err != nil {
			return nil, err
		}
		e.Reason = domain.ArchiveReason(reason)
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *ItemRepo) ListCategoriesByOwner(ctx context.Context, ownerID uuid.UUID) ([]string, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT category_name FROM items
		WHERE owner_id = $1 AND category_name <> ''
		ORDER BY category_name
	`, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var c string
		if err := rows.Scan(&c); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func scanItem(row pgx.Row) (*domain.Item, error) {
	var (
		item      domain.Item
		status    string
		reason    *string
	)
	err := row.Scan(
		&item.ID, &item.OwnerID, &item.Name, &item.Description, &item.CategoryName, &item.Quantity,
		&status, &reason, &item.ArchivedAt, &item.ExpirationDate, &item.ImageURL,
		&item.CreatedAt, &item.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	item.Status = domain.ItemStatus(status)
	if reason != nil {
		r := domain.ArchiveReason(*reason)
		item.ArchiveReason = &r
	}
	return &item, nil
}

func archiveReasonToDB(r *domain.ArchiveReason) *string {
	if r == nil {
		return nil
	}
	s := string(*r)
	return &s
}
