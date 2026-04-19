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

type UserRepo struct {
	pool *pgxpool.Pool
}

func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

const userColumns = `id, email, name, avatar_url, password_hash, telegram_sub, created_at, updated_at`

func (r *UserRepo) Create(ctx context.Context, user *domain.User) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO users (id, email, name, avatar_url, password_hash, telegram_sub, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, user.ID, user.Email, user.Name, user.AvatarURL, user.PasswordHash, user.TelegramSub, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return mapPgError(err, "users_email_key", domain.ErrEmailAlreadyUsed)
	}
	return nil
}

func (r *UserRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE id = $1`, id)
	return scanUser(row)
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE email = $1`, email)
	return scanUser(row)
}

func (r *UserRepo) FindByTelegramSub(ctx context.Context, sub string) (*domain.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE telegram_sub = $1`, sub)
	return scanUser(row)
}

// UpdateProfile обновляет только те поля, которые заданы в patch (non-nil).
// Пустая строка в Name считается ошибкой на уровне usecase — репо не валидирует.
func (r *UserRepo) UpdateProfile(ctx context.Context, id uuid.UUID, patch usecase.UserProfileUpdate, now time.Time) (*domain.User, error) {
	tag, err := r.pool.Exec(ctx, `
		UPDATE users SET
			name       = COALESCE($2, name),
			avatar_url = CASE WHEN $3::BOOLEAN THEN NULLIF($4::text, '') ELSE avatar_url END,
			updated_at = $5
		WHERE id = $1
	`, id, patch.Name, patch.AvatarURL != nil, deref(patch.AvatarURL), now)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, domain.ErrNotFound
	}
	return r.FindByID(ctx, id)
}

func scanUser(row pgx.Row) (*domain.User, error) {
	var u domain.User
	err := row.Scan(&u.ID, &u.Email, &u.Name, &u.AvatarURL, &u.PasswordHash, &u.TelegramSub, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, domain.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func deref(s *string) any {
	if s == nil {
		return nil
	}
	return *s
}
