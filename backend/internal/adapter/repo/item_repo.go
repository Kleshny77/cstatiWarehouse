package repo

import (
	"context"
	"database/sql"
	"errors"
	"strconv"
	"time"

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

const itemColumns = `id, organization_id, held_by_user_id, name, description, category_name, quantity, status, archive_reason, archived_at, expiration_date, image_url, location_address, parent_item_id, variant_label, measure_unit, volume_per_unit, created_at, updated_at`

func (r *ItemRepo) Create(ctx context.Context, item *domain.Item) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO items (id, organization_id, held_by_user_id, name, description, category_name, quantity, status, archive_reason, archived_at, expiration_date, image_url, location_address, parent_item_id, variant_label, measure_unit, volume_per_unit, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
	`,
		item.ID, item.OrganizationID, item.HeldByUserID, item.Name, item.Description, item.CategoryName, item.Quantity,
		string(item.Status), archiveReasonToDB(item.ArchiveReason), item.ArchivedAt,
		item.ExpirationDate, item.ImageURL, item.LocationAddress, item.ParentItemID, item.VariantLabel, string(item.MeasureUnit), item.VolumePerUnit,
		item.CreatedAt, item.UpdatedAt,
	)
	return err
}

func (r *ItemRepo) Update(ctx context.Context, item *domain.Item, expectedUpdatedAt *time.Time) error {
	query := `
		UPDATE items SET
			held_by_user_id = $2, name = $3, description = $4, category_name = $5, quantity = $6,
			status = $7, archive_reason = $8, archived_at = $9,
			expiration_date = $10, image_url = $11, location_address = $12,
			parent_item_id = $13, variant_label = $14, measure_unit = $15, volume_per_unit = $16,
			updated_at = $17
		WHERE id = $1`
	args := []any{
		item.ID, item.HeldByUserID, item.Name, item.Description, item.CategoryName, item.Quantity,
		string(item.Status), archiveReasonToDB(item.ArchiveReason), item.ArchivedAt,
		item.ExpirationDate, item.ImageURL, item.LocationAddress,
		item.ParentItemID, item.VariantLabel, string(item.MeasureUnit), item.VolumePerUnit,
		item.UpdatedAt,
	}
	if expectedUpdatedAt != nil {
		query += ` AND updated_at = $18`
		args = append(args, *expectedUpdatedAt)
	}

	tag, err := r.pool.Exec(ctx, query, args...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		if expectedUpdatedAt != nil {
			cur, ferr := r.FindByID(ctx, item.ID)
			if ferr != nil {
				return ferr
			}
			if cur == nil {
				return domain.ErrNotFound
			}
			return &domain.ItemVersionConflictError{ServerItem: *cur}
		}
		return domain.ErrNotFound
	}
	return nil
}

func (r *ItemRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Item, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+itemColumns+` FROM items WHERE id = $1`, id)
	return scanItem(row)
}

func (r *ItemRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID, filter usecase.ItemFilter) ([]domain.Item, error) {
	query := `SELECT ` + itemColumns + ` FROM items WHERE organization_id = $1`
	args := []any{orgID}
	if filter.Status != nil {
		args = append(args, string(*filter.Status))
		query += ` AND status = $` + strconv.Itoa(len(args))
	}
	if filter.HeldByUserID != nil {
		args = append(args, *filter.HeldByUserID)
		query += ` AND held_by_user_id = $` + strconv.Itoa(len(args))
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

func (r *ItemRepo) HasChildRows(ctx context.Context, parentID uuid.UUID) (bool, error) {
	var n int64
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*)::bigint FROM items WHERE parent_item_id = $1`, parentID).Scan(&n)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (r *ItemRepo) CountInStockChildrenWithPositiveQuantity(ctx context.Context, parentID uuid.UUID) (int64, error) {
	var n int64
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*)::bigint FROM items
		WHERE parent_item_id = $1 AND status = 'in_stock' AND quantity > 0
	`, parentID).Scan(&n)
	if err != nil {
		return 0, err
	}
	return n, nil
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
		INSERT INTO item_archive_events (id, item_id, organization_id, archived_by_user_id, quantity, reason, reason_detail, event_id, archived_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`,
		event.ID, event.ItemID, event.OrganizationID, event.ArchivedByUserID, event.Quantity,
		string(event.Reason), event.ReasonDetail, event.EventID, event.ArchivedAt,
	); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *ItemRepo) ListArchiveEvents(ctx context.Context, orgID uuid.UUID, limit, offset int) ([]domain.ArchiveEvent, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT
			e.id,
			e.item_id,
			e.organization_id,
			e.archived_by_user_id,
			e.quantity,
			e.reason,
			e.reason_detail,
			e.event_id,
			e.archived_at,
			i.name AS item_name,
			COALESCE(NULLIF(TRIM(u.name), ''), u.email, '') AS archived_by_display_name
		FROM item_archive_events e
		INNER JOIN items i ON i.id = e.item_id AND i.organization_id = e.organization_id
		INNER JOIN users u ON u.id = e.archived_by_user_id
		WHERE e.organization_id = $1
		ORDER BY e.archived_at DESC
		LIMIT $2 OFFSET $3
	`, orgID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.ArchiveEvent
	for rows.Next() {
		var e domain.ArchiveEvent
		var reason string
		if err := rows.Scan(
			&e.ID, &e.ItemID, &e.OrganizationID, &e.ArchivedByUserID,
			&e.Quantity, &reason, &e.ReasonDetail, &e.EventID, &e.ArchivedAt,
			&e.ItemName, &e.ArchivedByDisplayName,
		); err != nil {
			return nil, err
		}
		e.Reason = domain.ArchiveReason(reason)
		out = append(out, e)
	}
	return out, rows.Err()
}

func scanItem(row pgx.Row) (*domain.Item, error) {
	var (
		item       domain.Item
		status     string
		reason     *string
		parentID   sql.NullString
		variantLbl string
		measureRaw string
		volume     sql.NullFloat64
	)
	err := row.Scan(
		&item.ID, &item.OrganizationID, &item.HeldByUserID, &item.Name, &item.Description, &item.CategoryName, &item.Quantity,
		&status, &reason, &item.ArchivedAt, &item.ExpirationDate, &item.ImageURL, &item.LocationAddress,
		&parentID, &variantLbl, &measureRaw, &volume,
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
	if parentID.Valid {
		pid, err := uuid.Parse(parentID.String)
		if err != nil {
			return nil, err
		}
		item.ParentItemID = &pid
	}
	item.VariantLabel = variantLbl
	if mu, ok := domain.ParseMeasureUnit(measureRaw); ok {
		item.MeasureUnit = mu
	} else {
		item.MeasureUnit = domain.MeasureUnitPiece
	}
	if volume.Valid {
		v := volume.Float64
		item.VolumePerUnit = &v
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
