package repo

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type OrganizationRepo struct {
	pool *pgxpool.Pool
}

func NewOrganizationRepo(pool *pgxpool.Pool) *OrganizationRepo {
	return &OrganizationRepo{pool: pool}
}

const orgColumns = `id, name, owner_id, is_personal, created_at, updated_at`

func (r *OrganizationRepo) Create(ctx context.Context, org *domain.Organization) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO organizations (id, name, owner_id, is_personal, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, org.ID, org.Name, org.OwnerID, org.IsPersonal, org.CreatedAt, org.UpdatedAt)
	return err
}

func (r *OrganizationRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Organization, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+orgColumns+` FROM organizations WHERE id = $1`, id)
	return scanOrganization(row)
}

func (r *OrganizationRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]usecase.OrganizationWithRole, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT o.id, o.name, o.owner_id, o.is_personal, o.created_at, o.updated_at, m.role
		FROM organizations o
		JOIN organization_members m ON m.organization_id = o.id
		WHERE m.user_id = $1
		ORDER BY o.is_personal DESC, o.created_at ASC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []usecase.OrganizationWithRole
	for rows.Next() {
		var (
			org  domain.Organization
			role string
		)
		if err := rows.Scan(&org.ID, &org.Name, &org.OwnerID, &org.IsPersonal, &org.CreatedAt, &org.UpdatedAt, &role); err != nil {
			return nil, err
		}
		out = append(out, usecase.OrganizationWithRole{
			Organization: org,
			Role:         domain.OrgRole(role),
		})
	}
	return out, rows.Err()
}

func (r *OrganizationRepo) Update(ctx context.Context, id uuid.UUID, patch usecase.OrganizationPatch, now time.Time) (*domain.Organization, error) {
	tag, err := r.pool.Exec(ctx, `
		UPDATE organizations SET
			name       = COALESCE($2, name),
			updated_at = $3
		WHERE id = $1
	`, id, patch.Name, now)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, domain.ErrNotFound
	}
	return r.FindByID(ctx, id)
}

func (r *OrganizationRepo) SetOwner(ctx context.Context, id, newOwnerID uuid.UUID, now time.Time) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE organizations SET owner_id = $2, updated_at = $3 WHERE id = $1
	`, id, newOwnerID, now)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *OrganizationRepo) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM organizations WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *OrganizationRepo) TransferOwnershipAtomic(ctx context.Context, orgID, fromID, toID uuid.UUID, now time.Time) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	tag, err := tx.Exec(ctx,
		`UPDATE organization_members SET role = 'owner' WHERE organization_id = $1 AND user_id = $2`,
		orgID, toID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}

	if _, err := tx.Exec(ctx,
		`UPDATE organization_members SET role = 'admin' WHERE organization_id = $1 AND user_id = $2`,
		orgID, fromID,
	); err != nil {
		return err
	}

	if _, err := tx.Exec(ctx,
		`UPDATE organizations SET owner_id = $2, updated_at = $3 WHERE id = $1`,
		orgID, toID, now,
	); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func scanOrganization(row pgx.Row) (*domain.Organization, error) {
	var org domain.Organization
	err := row.Scan(&org.ID, &org.Name, &org.OwnerID, &org.IsPersonal, &org.CreatedAt, &org.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &org, nil
}
