package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
	"github.com/Kleshny77/cstatiWarehouse/backend/pkg/apierror"
)

type contextKey int

const (
	ctxKeyUserID contextKey = iota
)

type statusRecorder struct {
	http.ResponseWriter
	status int
	wrote  bool
}

func (r *statusRecorder) WriteHeader(code int) {
	if !r.wrote {
		r.status = code
		r.wrote = true
	}
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if !r.wrote {
		r.status = http.StatusOK
		r.wrote = true
	}
	return r.ResponseWriter.Write(b)
}

func recoverMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.ErrorContext(r.Context(), "panic recovered", "value", rec, "stack", string(debug.Stack()))
				writeHTTPError(w, apierror.InternalError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)
		pathLog := r.URL.Path
		if r.URL.RawQuery != "" {
			pathLog += "?[query_redacted]"
		}
		slog.InfoContext(r.Context(), "http request",
			"method", r.Method,
			"path", pathLog,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

func authMiddleware(tokens usecase.TokenIssuer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				writeError(w, r, domain.ErrUnauthorized)
				return
			}
			raw := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
			userID, err := tokens.ParseAccessToken(raw)
			if err != nil {
				writeError(w, r, domain.ErrUnauthorized)
				return
			}
			ctx := context.WithValue(r.Context(), ctxKeyUserID, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func currentUserID(r *http.Request) (uuid.UUID, bool) {
	id, ok := r.Context().Value(ctxKeyUserID).(uuid.UUID)
	return id, ok
}
