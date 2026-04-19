package db

import (
	"context"
	"database/sql"
	"fmt"

	// pgx stdlib driver for goose.
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"github.com/Kleshny77/cstatiWarehouse/backend/migrations"
)

const migrationsDir = "."

func openSQL(dsn string) (*sql.DB, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sql db: %w", err)
	}
	return db, nil
}

func setupGoose() error {
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("set dialect: %w", err)
	}
	return nil
}

// RunMigrationsUp накатывает все pending-миграции.
func RunMigrationsUp(ctx context.Context, dsn string) error {
	db, err := openSQL(dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	if err := setupGoose(); err != nil {
		return err
	}
	return goose.UpContext(ctx, db, migrationsDir)
}

// RunMigrationsDown откатывает одну миграцию назад.
func RunMigrationsDown(ctx context.Context, dsn string) error {
	db, err := openSQL(dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	if err := setupGoose(); err != nil {
		return err
	}
	return goose.DownContext(ctx, db, migrationsDir)
}

// MigrationsStatus выводит в stdout список миграций и их статус.
func MigrationsStatus(ctx context.Context, dsn string) error {
	db, err := openSQL(dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	if err := setupGoose(); err != nil {
		return err
	}
	return goose.StatusContext(ctx, db, migrationsDir)
}
