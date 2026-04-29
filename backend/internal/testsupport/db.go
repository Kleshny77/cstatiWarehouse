//go:build integration

// Package testsupport содержит утилиты для integration-тестов.
// Доступен только под build tag "integration".
package testsupport

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/db"
)

const (
	defaultTestDatabaseURL = "postgres://cstati:cstati@localhost:5432/cstatiwarehouse_test?sslmode=disable"
	adminDatabaseURL       = "postgres://cstati:cstati@localhost:5432/postgres?sslmode=disable"
	testDatabaseName       = "cstatiwarehouse_test"
)

// integrationBootstrapMu сериализует создание тестовой БД и прогон миграций, чтобы при параллельных
// пакетах не было гонок на CREATE DATABASE / DDL миграций.
var integrationBootstrapMu sync.Mutex

func DatabaseURL() string {
	if v := os.Getenv("TEST_DATABASE_URL"); v != "" {
		return v
	}
	return defaultTestDatabaseURL
}

func ensureDatabase(t *testing.T) {
	t.Helper()

	admin, err := sql.Open("pgx", adminDatabaseURL)
	if err != nil {
		t.Skipf("no postgres available on localhost:5432 (docker compose up?): %v", err)
	}
	defer admin.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := admin.PingContext(ctx); err != nil {
		t.Skipf("postgres not reachable (docker compose up?): %v", err)
	}

	var exists bool
	if err := admin.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = $1)`, testDatabaseName).Scan(&exists); err != nil {
		t.Fatalf("check database exists: %v", err)
	}
	if exists {
		return
	}
	if _, err := admin.ExecContext(ctx, `CREATE DATABASE `+testDatabaseName); err != nil {
		// Параллельные пакеты могли создать БД между SELECT и CREATE.
		if strings.Contains(err.Error(), "23505") {
			return
		}
		t.Fatalf("create test database: %v", err)
	}
}

func SetupDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	integrationBootstrapMu.Lock()
	defer integrationBootstrapMu.Unlock()

	ensureDatabase(t)
	ctx := context.Background()
	if err := db.RunMigrationsUp(ctx, DatabaseURL()); err != nil {
		t.Fatalf("run migrations: %v", err)
	}

	pool, err := pgxpool.New(ctx, DatabaseURL())
	if err != nil {
		t.Fatalf("connect pool: %v", err)
	}
	t.Cleanup(pool.Close)

	truncate(t, pool)
	return pool
}

func truncate(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	stmt := strings.Join([]string{
		"TRUNCATE",
		"activity_log,",
		"categories,",
		"item_archive_events,",
		"events,",
		"organization_invites,",
		"items,",
		"organization_members,",
		"organizations,",
		"refresh_tokens,",
		"device_push_tokens,",
		"users",
		"RESTART IDENTITY CASCADE",
	}, " ")
	if _, err := pool.Exec(context.Background(), stmt); err != nil {
		t.Fatalf("truncate tables: %v", err)
	}
}
