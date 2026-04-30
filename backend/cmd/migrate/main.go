package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/config"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/db"
)

func main() {
	if err := run(); err != nil {
		slog.Error("migrate failed", "err", err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) < 2 {
		return fmt.Errorf("usage: migrate <up|down|status>")
	}

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx := context.Background()
	switch os.Args[1] {
	case "up":
		return db.RunMigrationsUp(ctx, cfg.DatabaseURL)
	case "down":
		return db.RunMigrationsDown(ctx, cfg.DatabaseURL)
	case "status":
		return db.MigrationsStatus(ctx, cfg.DatabaseURL)
	default:
		return fmt.Errorf("unknown command %q (expected up|down|status)", os.Args[1])
	}
}
