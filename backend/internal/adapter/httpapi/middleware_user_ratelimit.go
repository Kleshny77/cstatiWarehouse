package httpapi

import (
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/ratelimit"
	"golang.org/x/time/rate"
)

func userRateLimitMiddleware(limiter *ratelimit.UserLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := currentUserID(r)
			if !ok {
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

func NewUserRateLimiter(r float64, burst int, ttl time.Duration) *ratelimit.UserLimiter {
	return ratelimit.NewUserLimiter(rate.Limit(r), burst, ttl)
}
