package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/httpapi"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/telegram"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/clock"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/config"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/db"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/invitecode"
	infrajwt "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/password"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

func main() {
	if err := run(); err != nil {
		slog.Error("server exited with error", "err", err)
		os.Exit(1)
	}
}

func run() error {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	slog.Info("running migrations")
	if err := db.RunMigrationsUp(ctx, cfg.DatabaseURL); err != nil {
		return fmt.Errorf("migrations failed: %w", err)
	}

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	userRepo := repo.NewUserRepo(pool)
	refreshRepo := repo.NewRefreshTokenRepo(pool)
	itemRepo := repo.NewItemRepo(pool)
	orgRepo := repo.NewOrganizationRepo(pool)
	memberRepo := repo.NewMemberRepo(pool)
	inviteRepo := repo.NewInviteRepo(pool)
	eventRepo := repo.NewEventRepo(pool)
	categoryRepo := repo.NewCategoryRepo(pool)
	activityRepo := repo.NewActivityRepo(pool)

	issuer := infrajwt.NewIssuer(cfg.JWTSecret, cfg.JWTAccessTTL)
	refreshGen := infrajwt.NewRefreshGenerator()
	hasher := password.NewBcryptHasher(12)

	var verifier usecase.TelegramVerifier
	if cfg.TelegramConfigured() {
		v, err := telegram.NewJWKSVerifier(ctx, cfg.TelegramJWKSURL, cfg.TelegramIssuer, cfg.TelegramClientID)
		if err != nil {
			return err
		}
		verifier = v
	}

	inviteGen := invitecode.NewGenerator(invitecode.DefaultLength)
	organizationsUC := usecase.NewOrganizationsUseCase(orgRepo, memberRepo, inviteRepo, inviteGen, clock.Real{}).
		WithActivity(activityRepo)

	authUC := usecase.NewAuthUseCase(
		userRepo, refreshRepo, organizationsUC, hasher, issuer, refreshGen, verifier, clock.Real{},
		usecase.AuthConfig{
			RefreshTTL:         cfg.JWTRefreshTTL,
			TelegramConfigured: cfg.TelegramConfigured(),
		},
	)
	warehouseUC := usecase.NewWarehouseUseCase(itemRepo, memberRepo, clock.Real{}).
		WithActivity(activityRepo).
		WithEvents(eventRepo)
	eventsUC := usecase.NewEventsUseCase(eventRepo, memberRepo, activityRepo, clock.Real{})
	categoriesUC := usecase.NewCategoriesUseCase(categoryRepo, memberRepo, activityRepo, clock.Real{})
	activityUC := usecase.NewActivityUseCase(activityRepo, memberRepo)

	uploadsHandler := httpapi.NewUploadsHandler(cfg.UploadsDir, cfg.PublicBaseURL, cfg.MaxUploadBytes)

	handler := httpapi.NewRouter(httpapi.RouterDeps{
		Auth:          httpapi.NewAuthHandler(authUC),
		Warehouse:     httpapi.NewWarehouseHandler(warehouseUC),
		Organizations: httpapi.NewOrganizationHandler(organizationsUC),
		Events:        httpapi.NewEventsHandler(eventsUC),
		Categories:    httpapi.NewCategoriesHandler(categoriesUC),
		Activity:      httpapi.NewActivityHandler(activityUC),
		Uploads:       uploadsHandler,
		Tokens:        issuer,
	})

	server := &http.Server{
		Addr:         cfg.HTTPAddr,
		Handler:      handler,
		ReadTimeout:  cfg.HTTPReadTimeout,
		WriteTimeout: cfg.HTTPWriteTimeout,
	}

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("http server listening", "addr", cfg.HTTPAddr, "telegram_configured", cfg.TelegramConfigured())
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	select {
	case <-ctx.Done():
		slog.Info("shutdown signal received")
	case err := <-serverErr:
		return err
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.HTTPShutdownTimeout)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		return err
	}
	return nil
}
