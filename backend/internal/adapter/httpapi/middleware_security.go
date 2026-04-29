package httpapi

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// securityHeadersMiddleware — снижает риск MIME-sniffing, встраивания в iframe и лишних capability в WebView.
func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}

// authRateLimitMiddleware ограничивает частоту POST к публичным эндпоинтам входа (защита от перебора и спама).
// clientIP возвращает строку IP для лимита (например из X-Forwarded-For за доверенным прокси).
func authRateLimitMiddleware(limiter *perIPRateLimiter, clientIP func(*http.Request) string) func(http.Handler) http.Handler {
	if clientIP == nil {
		clientIP = remoteIPForRateLimit
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if shouldThrottleAuthRoute(r) && !limiter.Allow(clientIP(r)) {
				w.Header().Set("Retry-After", "60")
				writeJSON(w, http.StatusTooManyRequests, errorBody{
					Error:   "rate_limited",
					Message: "too many requests, try again later",
				})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func shouldThrottleAuthRoute(r *http.Request) bool {
	if r.Method != http.MethodPost {
		return false
	}
	switch r.URL.Path {
	case "/auth/register", "/auth/login", "/auth/telegram", "/auth/google", "/auth/refresh":
		return true
	default:
		return false
	}
}

func remoteIPForRateLimit(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return strings.TrimSpace(r.RemoteAddr)
	}
	return host
}

// perIPRateLimiter — отдельный token bucket на IP (грубая защита по памяти: при переполнении карта сбрасывается).
type perIPRateLimiter struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	interval time.Duration
	burst    int
}

func newPerIPRateLimiter(interval time.Duration, burst int) *perIPRateLimiter {
	return &perIPRateLimiter{
		limiters: make(map[string]*rate.Limiter),
		interval: interval,
		burst:    burst,
	}
}

func (p *perIPRateLimiter) Allow(ip string) bool {
	p.mu.Lock()
	lim, ok := p.limiters[ip]
	if !ok {
		lim = rate.NewLimiter(rate.Every(p.interval), p.burst)
		p.limiters[ip] = lim
		if len(p.limiters) > 4096 {
			p.limiters = make(map[string]*rate.Limiter)
		}
	}
	p.mu.Unlock()
	return lim.Allow()
}
