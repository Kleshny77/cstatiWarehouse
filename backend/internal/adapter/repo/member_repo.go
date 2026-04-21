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

type MemberRepo struct {
	pool *pgxpool.Pool
}

func NewMemberRepo(pool *pgxpool.Pool) *MemberRepo {
	return &MemberRepo{pool: pool}
}

func (r *MemberRepo) Add(ctx context.Context, m *domain.OrganizationMember) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO organization_members (organization_id, user_id, role, joined_at)
		VALUES ($1, $2, $3, $4)
	`, m.OrganizationID, m.UserID, string(m.Role), m.JoinedAt)
	if err != nil {
		return mapPgError(err, "organization_members_pkey", domain.ErrAlreadyMember)
	}
	return nil
}

func (r *MemberRepo) Remove(ctx context.Context, orgID, userID uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `
		DELETE FROM organization_members WHERE organization_id = $1 AND user_id = $2
	`, orgID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *MemberRepo) UpdateRole(ctx context.Context, orgID, userID uuid.UUID, role domain.OrgRole) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE organization_members SET role = $3
		WHERE organization_id = $1 AND user_id = $2
	`, orgID, userID, string(role))
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *MemberRepo) FindRole(ctx context.Context, orgID, userID uuid.UUID) (domain.OrgRole, error) {
	var role string
	err := r.pool.QueryRow(ctx, `
		SELECT role FROM organization_members
		WHERE organization_id = $1 AND user_id = $2
	`, orgID, userID).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", domain.ErrNotFound
	}
	if err != nil {
		return "", err
	}
	return domain.OrgRole(role), nil
}

func (r *MemberRepo) ListWithProfilesByOrganization(ctx context.Context, orgID uuid.UUID) ([]usecase.MemberWithProfile, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT m.organization_id, m.user_id, m.role, m.joined_at, u.name, u.last_name, u.email, u.avatar_url
		FROM organization_members m
		JOIN users u ON u.id = m.user_id
		WHERE m.organization_id = $1
		ORDER BY m.joined_at ASC
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []usecase.MemberWithProfile
	for rows.Next() {
		var (
			m        domain.OrganizationMember
			role     string
			name     string
			lastName string
			email    string
			avatar   *string
		)
		if err := rows.Scan(&m.OrganizationID, &m.UserID, &role, &m.JoinedAt, &name, &lastName, &email, &avatar); err != nil {
			return nil, err
		}
		m.Role = domain.OrgRole(role)
		out = append(out, usecase.MemberWithProfile{
			Member:    m,
			Name:      name,
			LastName:  lastName,
			Email:     email,
			AvatarURL: avatar,
		})
	}
	return out, rows.Err()
}

func (r *MemberRepo) ListByOrganization(ctx context.Context, orgID uuid.UUID) ([]domain.OrganizationMember, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT organization_id, user_id, role, joined_at
		FROM organization_members
		WHERE organization_id = $1
		ORDER BY joined_at ASC
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.OrganizationMember
	for rows.Next() {
		var (
			m    domain.OrganizationMember
			role string
		)
		if err := rows.Scan(&m.OrganizationID, &m.UserID, &role, &m.JoinedAt); err != nil {
			return nil, err
		}
		m.Role = domain.OrgRole(role)
		out = append(out, m)
	}
	return out, rows.Err()
}
