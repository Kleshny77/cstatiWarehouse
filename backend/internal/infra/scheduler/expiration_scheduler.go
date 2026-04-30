// Package scheduler provides background job scheduling for periodic tasks
// like expiration notifications.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ExpirationTicker struct {
	uc       *usecase.ExpirationNotificationsUseCase
	interval time.Duration
	logger   *slog.Logger

	mu      sync.Mutex
	running bool
	stopCh  chan struct{}
	doneCh  chan struct{}
}

func NewExpirationTicker(uc *usecase.ExpirationNotificationsUseCase, interval time.Duration, logger *slog.Logger) *ExpirationTicker {
	if interval <= 0 {
		interval = 15 * time.Minute
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &ExpirationTicker{
		uc:       uc,
		interval: interval,
		logger:   logger,
	}
}

func (t *ExpirationTicker) Start(ctx context.Context) {
	t.mu.Lock()
	if t.running {
		t.mu.Unlock()
		return
	}
	t.running = true
	t.stopCh = make(chan struct{})
	t.doneCh = make(chan struct{})
	t.mu.Unlock()

	go t.loop(ctx)
}

func (t *ExpirationTicker) Stop() {
	t.mu.Lock()
	if !t.running {
		t.mu.Unlock()
		return
	}
	close(t.stopCh)
	done := t.doneCh
	t.running = false
	t.mu.Unlock()
	<-done
}

func (t *ExpirationTicker) loop(ctx context.Context) {
	defer close(t.doneCh)

	t.runTick(ctx)

	ticker := time.NewTicker(t.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.stopCh:
			return
		case <-ticker.C:
			t.runTick(ctx)
		}
	}
}

func (t *ExpirationTicker) runTick(ctx context.Context) {
	tickCtx, cancel := context.WithTimeout(ctx, t.interval-time.Second)
	defer cancel()

	res, err := t.uc.Tick(tickCtx)
	if err != nil {
		t.logger.ErrorContext(tickCtx, "expiration tick failed", "err", err)
		return
	}
	t.logger.InfoContext(tickCtx, "expiration tick complete",
		"scanned", res.Scanned,
		"sent", res.Sent,
		"skipped", res.Skipped,
		"failed", res.Failed,
		"duration_ms", res.Duration.Milliseconds(),
	)
}
