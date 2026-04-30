package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/googleid"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/httpapi"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/telegram"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/websocket"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/clock"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/config"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/db"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/invitecode"
	infrajwt "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/netutil"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/password"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/pushdispatch"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/scheduler"
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
	for _, w := range cfg.BindLANWarnings() {
		slog.Warn(w)
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
	pushTokenRepo := repo.NewDevicePushTokenRepo(pool)
	itemRepo := repo.NewItemRepo(pool)
	orgRepo := repo.NewOrganizationRepo(pool)
	memberRepo := repo.NewMemberRepo(pool)
	inviteRepo := repo.NewInviteRepo(pool)
	eventRepo := repo.NewEventRepo(pool)
	categoryRepo := repo.NewCategoryRepo(pool)
	activityRepo := repo.NewActivityRepo(pool)
	expirationNotifRepo := repo.NewExpirationNotificationRepo(pool)
	expirationCandidates := repo.NewExpirationCandidateAdapter(expirationNotifRepo)
	commentRepo := repo.NewCommentRepo(pool)
	reservationRepo := repo.NewReservationRepo(pool)

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

	var googleVerifier usecase.GoogleVerifier
	if cfg.GoogleConfigured() {
		v, err := googleid.NewVerifier(ctx, cfg.GoogleClientID)
		if err != nil {
			return err
		}
		googleVerifier = v
	}

	inviteGen := invitecode.NewGenerator(invitecode.DefaultLength)
	organizationsUC := usecase.NewOrganizationsUseCase(orgRepo, memberRepo, inviteRepo, inviteGen, clock.Real{}).
		WithActivity(activityRepo)

	authUC := usecase.NewAuthUseCase(
		userRepo, refreshRepo, organizationsUC, hasher, issuer, refreshGen,
		verifier, googleVerifier, clock.Real{},
		usecase.AuthConfig{
			RefreshTTL:         cfg.JWTRefreshTTL,
			TelegramConfigured: cfg.TelegramConfigured(),
			GoogleConfigured:   cfg.GoogleConfigured(),
		},
	)

	wsHub := websocket.NewHub()
	go wsHub.Run()
	wsBroadcaster := websocket.NewBroadcaster(wsHub)

	warehouseUC := usecase.NewWarehouseUseCase(itemRepo, memberRepo, clock.Real{}).
		WithActivity(activityRepo).
		WithEvents(eventRepo).
		WithBroadcaster(wsBroadcaster)
	eventsUC := usecase.NewEventsUseCase(eventRepo, memberRepo, activityRepo, clock.Real{})
	categoriesUC := usecase.NewCategoriesUseCase(categoryRepo, memberRepo, activityRepo, clock.Real{})
	activityUC := usecase.NewActivityUseCase(activityRepo, memberRepo)
	analyticsUC := usecase.NewAnalyticsUseCase(itemRepo, memberRepo, activityRepo)
	pushDispatcher := pushdispatch.NewLoggingDispatcher(slog.Default())
	expirationNotifUC := usecase.NewExpirationNotificationsUseCase(
		expirationNotifRepo, expirationCandidates, pushDispatcher, clock.Real{},
	)
	commentsUC := usecase.NewCommentsUseCase(commentRepo, itemRepo, memberRepo, clock.Real{}).
		WithBroadcaster(wsBroadcaster)
	reservationsUC := usecase.NewReservationsUseCase(reservationRepo, itemRepo, memberRepo, eventRepo, clock.Real{}).
		WithBroadcaster(wsBroadcaster)

	expirationTicker := scheduler.NewExpirationTicker(expirationNotifUC, 15*time.Minute, slog.Default())
	expirationTicker.Start(ctx)
	defer expirationTicker.Stop()

	reservationExpirationTicker := scheduler.NewReservationExpirationTicker(reservationsUC, 5*time.Minute, slog.Default())
	reservationExpirationTicker.Start(ctx)
	defer reservationExpirationTicker.Stop()

	uploadSigner := infrajwt.NewUploadURLSigner(cfg.EffectiveUploadSigningSecret(), cfg.UploadURLTTL)
	uploadsHandler := httpapi.NewUploadsHandler(cfg.UploadsDir, cfg.PublicBaseURL, cfg.MaxUploadBytes, uploadSigner)

	proxies, err := netutil.ParseTrustedProxyCIDRs(cfg.TrustedProxyCIDRsRaw)
	if err != nil {
		return fmt.Errorf("TRUSTED_PROXY_CIDRS: %w", err)
	}
	var clientIP func(*http.Request) string
	if strings.TrimSpace(cfg.TrustedProxyCIDRsRaw) != "" {
		clientIP = proxies.ClientIP
	}

	userLimiter := httpapi.NewUserRateLimiter(50, 100, 5*time.Minute)

	handler := httpapi.NewRouter(httpapi.RouterDeps{
		Auth:                    httpapi.NewAuthHandler(authUC),
		Warehouse:               httpapi.NewWarehouseHandler(warehouseUC),
		Organizations:           httpapi.NewOrganizationHandler(organizationsUC),
		Events:                  httpapi.NewEventsHandler(eventsUC),
		Categories:              httpapi.NewCategoriesHandler(categoriesUC),
		Activity:                httpapi.NewActivityHandler(activityUC),
		Analytics:               httpapi.NewAnalyticsHandler(analyticsUC),
		Uploads:                 uploadsHandler,
		Notifications:           httpapi.NewNotificationsHandler(pushTokenRepo),
		ExpirationNotifications: httpapi.NewExpirationNotificationsHandler(expirationNotifUC),
		Comments:                httpapi.NewCommentsHandler(commentsUC),
		Reservations:            httpapi.NewReservationsHandler(reservationsUC),
		WebSocket:               httpapi.NewWebSocketHandler(wsHub),
		Tokens:                  issuer,
		ClientIP:                clientIP,
		UserLimiter:             userLimiter,
		CORSAllowedOrigins:      cfg.ParsedCORSAllowedOrigins(),
	})

	listenAddr := normalizeListenAddrForGoDualStack(cfg.HTTPAddr)
	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", listenAddr, err)
	}

	server := &http.Server{
		Handler:           handler,
		ReadTimeout:       cfg.HTTPReadTimeout,
		ReadHeaderTimeout: 10 * time.Second,
		WriteTimeout:      cfg.HTTPWriteTimeout,
		IdleTimeout:       120 * time.Second,
	}

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("http server listening",
			"http_addr", cfg.HTTPAddr,
			"listen_addr", ln.Addr().String(),
			"telegram_configured", cfg.TelegramConfigured(),
			"google_configured", cfg.GoogleConfigured(),
		)
		if err := server.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
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

func normalizeListenAddrForGoDualStack(addr string) string {
	const pfx = "0.0.0.0:"
	if strings.HasPrefix(addr, pfx) {
		return ":" + strings.TrimPrefix(addr, pfx)
	}
	return addr
}
