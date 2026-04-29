package httpapi

import (
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/ratelimit"
	"golang.org/x/time/rate"
)

// userRateLimitMiddleware ограничивает количество запросов на пользователя
func userRateLimitMiddleware(limiter *ratelimit.UserLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := currentUserID(r)
			if !ok {
				// Если пользователь не аутентифицирован, пропускаем rate limiting
				// (для неаутентифицированных запросов используется IP-based limiting)
				next.ServeHTTP(w, r)
				return
			}

			if !limiter.Allow(userID) {
				writeError(w, r, domain.ErrTooManyRequests)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// NewUserRateLimiter создаёт rate limiter для пользователей
// rate: запросов в секунду на пользователя (рекомендуется 10-50)
// burst: максимальный burst (рекомендуется 20-100)
// ttl: время жизни неактивного лимитера (рекомендуется 1-5 минут)
func NewUserRateLimiter(r float64, burst int, ttl time.Duration) *ratelimit.UserLimiter {
	return ratelimit.NewUserLimiter(rate.Limit(r), burst, ttl)
}
