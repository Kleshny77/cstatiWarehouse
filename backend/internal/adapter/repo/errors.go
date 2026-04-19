package repo

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

// mapPgError превращает конкретные PG-ошибки в доменные, если совпадает имя
// constraint. Для всех остальных ошибок возвращает исходную.
func mapPgError(err error, constraint string, domainErr error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		if pgErr.Code == "23505" && pgErr.ConstraintName == constraint {
			return domainErr
		}
	}
	return err
}
