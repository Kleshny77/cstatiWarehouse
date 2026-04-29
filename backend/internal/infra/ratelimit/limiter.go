package ratelimit

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// PerIPLimiter — отдельный token bucket на IP
// Грубая защита по памяти: при переполнении карта сбрасывается
type PerIPLimiter struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	interval time.Duration
	burst    int
	maxIPs   int
}

// NewPerIPLimiter создаёт новый rate limiter с ограничением по IP
// interval - минимальный интервал между запросами
// burst - максимальное количество запросов в burst
// maxIPs - максимальное количество IP в памяти (при превышении карта сбрасывается)
func NewPerIPLimiter(interval time.Duration, burst int, maxIPs int) *PerIPLimiter {
	if maxIPs <= 0 {
		maxIPs = 4096
	}
	return &PerIPLimiter{
		limiters: make(map[string]*rate.Limiter),
		interval: interval,
		burst:    burst,
		maxIPs:   maxIPs,
	}
}

// Allow проверяет, разрешён ли запрос для данного IP
func (p *PerIPLimiter) Allow(ip string) bool {
	p.mu.Lock()
	lim, ok := p.limiters[ip]
	if !ok {
		lim = rate.NewLimiter(rate.Every(p.interval), p.burst)
		p.limiters[ip] = lim

		// Защита от переполнения памяти
		if len(p.limiters) > p.maxIPs {
			p.limiters = make(map[string]*rate.Limiter)
		}
	}
	p.mu.Unlock()

	return lim.Allow()
}

// Reset сбрасывает все лимиты (полезно для тестов)
func (p *PerIPLimiter) Reset() {
	p.mu.Lock()
	p.limiters = make(map[string]*rate.Limiter)
	p.mu.Unlock()
}

// Count возвращает количество отслеживаемых IP (для мониторинга)
func (p *PerIPLimiter) Count() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.limiters)
}
