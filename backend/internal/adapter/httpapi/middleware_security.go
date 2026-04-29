package httpapi

import (
	"net"
	"net/http"
	"strings"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/ratelimit"
	"github.com/Kleshny77/cstatiWarehouse/backend/pkg/apierror"
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
func authRateLimitMiddleware(limiter *ratelimit.PerIPLimiter, clientIP func(*http.Request) string) func(http.Handler) http.Handler {
	if clientIP == nil {
		clientIP = remoteIPForRateLimit
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if shouldThrottleAuthRoute(r) && !limiter.Allow(clientIP(r)) {
				w.Header().Set("Retry-After", "60")
				writeHTTPError(w, apierror.RateLimited)
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
