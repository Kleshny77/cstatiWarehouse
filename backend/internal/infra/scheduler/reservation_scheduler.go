package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ReservationExpirationTicker struct {
	uc       *usecase.ReservationsUseCase
	interval time.Duration
	logger   *slog.Logger

	mu      sync.Mutex
	running bool
	stopCh  chan struct{}
	doneCh  chan struct{}
}

func NewReservationExpirationTicker(
	uc *usecase.ReservationsUseCase,
	interval time.Duration,
	logger *slog.Logger,
) *ReservationExpirationTicker {
	if interval <= 0 {
		interval = 5 * time.Minute
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &ReservationExpirationTicker{
		uc:       uc,
		interval: interval,
		logger:   logger,
	}
}

func (t *ReservationExpirationTicker) Start(ctx context.Context) {
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

func (t *ReservationExpirationTicker) Stop() {
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

func (t *ReservationExpirationTicker) loop(ctx context.Context) {
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

func (t *ReservationExpirationTicker) runTick(ctx context.Context) {
	tickCtx, cancel := context.WithTimeout(ctx, t.interval-time.Second)
	defer cancel()

	res, err := t.uc.ExpireDueReservations(tickCtx)
	if err != nil {
		t.logger.ErrorContext(tickCtx, "reservation expiration tick failed", "err", err)
		return
	}
	if res.Scanned == 0 {
		return
	}
	t.logger.InfoContext(tickCtx, "reservation expiration tick complete",
		"scanned", res.Scanned,
		"expired", res.Expired,
		"failed", res.Failed,
	)
}
