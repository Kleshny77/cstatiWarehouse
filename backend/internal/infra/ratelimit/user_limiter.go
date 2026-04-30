package ratelimit

import (
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/time/rate"
)

type UserLimiter struct {
	limiters map[uuid.UUID]*rate.Limiter
	mu       sync.RWMutex
	rate     rate.Limit
	burst    int
	ttl time.Duration
	lastSeen map[uuid.UUID]time.Time
}

func NewUserLimiter(r rate.Limit, burst int, ttl time.Duration) *UserLimiter {
	ul := &UserLimiter{
		limiters: make(map[uuid.UUID]*rate.Limiter),
		lastSeen: make(map[uuid.UUID]time.Time),
		rate:     r,
		burst:    burst,
		ttl:      ttl,
	}

	if ttl > 0 {
		go ul.cleanupLoop()
	}

	return ul
}

func (ul *UserLimiter) Allow(userID uuid.UUID) bool {
	ul.mu.Lock()
	defer ul.mu.Unlock()

	limiter, exists := ul.limiters[userID]
	if !exists {
		limiter = rate.NewLimiter(ul.rate, ul.burst)
		ul.limiters[userID] = limiter
	}

	ul.lastSeen[userID] = time.Now()
	return limiter.Allow()
}

func (ul *UserLimiter) cleanupLoop() {
	ticker := time.NewTicker(ul.ttl)
	defer ticker.Stop()

	for range ticker.C {
		ul.cleanup()
	}
}

func (ul *UserLimiter) cleanup() {
	ul.mu.Lock()
	defer ul.mu.Unlock()

	now := time.Now()
	for userID, lastSeen := range ul.lastSeen {
		if now.Sub(lastSeen) > ul.ttl {
			delete(ul.limiters, userID)
			delete(ul.lastSeen, userID)
		}
	}
}

func (ul *UserLimiter) Count() int {
	ul.mu.RLock()
	defer ul.mu.RUnlock()
	return len(ul.limiters)
}
