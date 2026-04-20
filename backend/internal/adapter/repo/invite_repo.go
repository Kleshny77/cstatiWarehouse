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

type InviteRepo struct {
	pool *pgxpool.Pool
}

func NewInviteRepo(pool *pgxpool.Pool) *InviteRepo {
	return &InviteRepo{pool: pool}
}

const inviteColumns = `id, organization_id, code, created_by_user_id, created_at, expires_at, max_uses, used_count, revoked_at`

func (r *InviteRepo) Create(ctx context.Context, invite *domain.Invite) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO organization_invites (id, organization_id, code, created_by_user_id, created_at, expires_at, max_uses, used_count, revoked_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, invite.ID, invite.OrganizationID, invite.Code, invite.CreatedByUserID, invite.CreatedAt,
		invite.ExpiresAt, invite.MaxUses, invite.UsedCount, invite.RevokedAt)
	return err
}

func (r *InviteRepo) FindByCode(ctx context.Context, code string) (*domain.Invite, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+inviteColumns+` FROM organization_invites WHERE code = $1`, code)
	return scanInvite(row)
}

func (r *InviteRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Invite, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+inviteColumns+` FROM organization_invites WHERE id = $1`, id)
	return scanInvite(row)
}

func (r *InviteRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.Invite, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+inviteColumns+` FROM organization_invites WHERE organization_id = $1 ORDER BY created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Invite
	for rows.Next() {
		inv, err := scanInviteRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *inv)
	}
	return out, rows.Err()
}

func (r *InviteRepo) IncrementUsed(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `UPDATE organization_invites SET used_count = used_count + 1 WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *InviteRepo) Revoke(ctx context.Context, id uuid.UUID, at time.Time) error {
	tag, err := r.pool.Exec(ctx, `UPDATE organization_invites SET revoked_at = $2 WHERE id = $1 AND revoked_at IS NULL`, id, at)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func scanInvite(row pgx.Row) (*domain.Invite, error) {
	inv, err := scanInviteRow(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	return inv, err
}

func scanInviteRow(row pgx.Row) (*domain.Invite, error) {
	var inv domain.Invite
	if err := row.Scan(&inv.ID, &inv.OrganizationID, &inv.Code, &inv.CreatedByUserID, &inv.CreatedAt,
		&inv.ExpiresAt, &inv.MaxUses, &inv.UsedCount, &inv.RevokedAt); err != nil {
		return nil, err
	}
	return &inv, nil
}
