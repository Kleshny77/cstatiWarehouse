//
// category_repo.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package repo

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type CategoryRepo struct {
	pool *pgxpool.Pool
}

func NewCategoryRepo(pool *pgxpool.Pool) *CategoryRepo {
	return &CategoryRepo{pool: pool}
}

const categoryColumns = "id, organization_id, created_by, name, created_at"

func (r *CategoryRepo) Create(ctx context.Context, c *domain.Category) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO categories (`+categoryColumns+`)
		VALUES ($1, $2, $3, $4, $5)
	`, c.ID, c.OrganizationID, c.CreatedByID, c.Name, c.CreatedAt)
	if err != nil {
		return mapPgError(err, "idx_categories_org_name_ci", domain.ErrConflict)
	}
	return nil
}

func (r *CategoryRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Category, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+categoryColumns+` FROM categories WHERE id = $1`, id)
	return scanCategoryRow(row)
}

func (r *CategoryRepo) FindByName(ctx context.Context, orgID uuid.UUID, name string) (*domain.Category, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+categoryColumns+` FROM categories
		WHERE organization_id = $1 AND lower(name) = lower($2)
	`, orgID, strings.TrimSpace(name))
	return scanCategoryRow(row)
}

func (r *CategoryRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Category, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+categoryColumns+` FROM categories
		WHERE organization_id = $1
		ORDER BY lower(name) ASC
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Category
	for rows.Next() {
		c, err := scanCategoryRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (r *CategoryRepo) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM categories WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func scanCategoryRow(row rowScanner) (*domain.Category, error) {
	var c domain.Category
	err := row.Scan(&c.ID, &c.OrganizationID, &c.CreatedByID, &c.Name, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}
