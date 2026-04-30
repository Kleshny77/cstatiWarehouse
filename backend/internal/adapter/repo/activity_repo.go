//
// activity_repo.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package repo

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type ActivityRepo struct {
	pool *pgxpool.Pool
}

func NewActivityRepo(pool *pgxpool.Pool) *ActivityRepo {
	return &ActivityRepo{pool: pool}
}

func (r *ActivityRepo) Append(ctx context.Context, e *domain.ActivityEntry) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO activity_log (id, organization_id, actor_user_id, kind, target_type, target_id, summary, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, e.ID, e.OrganizationID, e.ActorUserID, string(e.Kind), e.TargetType, e.TargetID, e.Summary, e.CreatedAt)
	return err
}

func (r *ActivityRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID, limit int) ([]domain.ActivityEntry, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := r.pool.Query(ctx, `
		SELECT
			a.id,
			a.organization_id,
			a.actor_user_id,
			COALESCE(NULLIF(TRIM(u.name), ''), u.email, '') AS actor_display_name,
			a.kind,
			a.target_type,
			a.target_id,
			a.summary,
			a.created_at
		FROM activity_log a
		INNER JOIN users u ON u.id = a.actor_user_id
		WHERE a.organization_id = $1
		ORDER BY a.created_at DESC
		LIMIT $2
	`, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.ActivityEntry
	for rows.Next() {
		var (
			e       domain.ActivityEntry
			kind    string
			target  string
			tgtID   *uuid.UUID
			summary string
			actorDN string
		)
		if err := rows.Scan(&e.ID, &e.OrganizationID, &e.ActorUserID, &actorDN, &kind, &target, &tgtID, &summary, &e.CreatedAt); err != nil {
			return nil, err
		}
		e.ActorDisplayName = actorDN
		e.Kind = domain.ActivityKind(kind)
		e.TargetType = target
		e.TargetID = tgtID
		e.Summary = summary
		out = append(out, e)
	}
	return out, rows.Err()
}
