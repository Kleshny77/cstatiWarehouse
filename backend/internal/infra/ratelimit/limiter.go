package ratelimit

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

type PerIPLimiter struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	interval time.Duration
	burst    int
	maxIPs   int
}

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

func (p *PerIPLimiter) Allow(ip string) bool {
	p.mu.Lock()
	lim, ok := p.limiters[ip]
	if !ok {
		lim = rate.NewLimiter(rate.Every(p.interval), p.burst)
		p.limiters[ip] = lim

		if len(p.limiters) > p.maxIPs {
			p.limiters = make(map[string]*rate.Limiter)
		}
	}
	p.mu.Unlock()

	return lim.Allow()
}

func (p *PerIPLimiter) Reset() {
	p.mu.Lock()
	p.limiters = make(map[string]*rate.Limiter)
	p.mu.Unlock()
}

func (p *PerIPLimiter) Count() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.limiters)
}
