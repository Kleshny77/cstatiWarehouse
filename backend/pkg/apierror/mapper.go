// Package apierror provides centralized HTTP error mapping for the API layer.
package apierror

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	infrajwt "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
)

// Response represents a structured API error response.
type Response struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// HTTPError represents an error with HTTP status code and API error response.
type HTTPError struct {
	StatusCode int
	Response   Response
}

// Common error responses that can be reused across handlers.
var (
	BadJSON = HTTPError{
		StatusCode: http.StatusBadRequest,
		Response:   Response{Error: "bad_json", Message: "invalid JSON body"},
	}
	RateLimited = HTTPError{
		StatusCode: http.StatusTooManyRequests,
		Response:   Response{Error: "rate_limited", Message: "too many requests"},
	}
	InternalError = HTTPError{
		StatusCode: http.StatusInternalServerError,
		Response:   Response{Error: "internal_error", Message: "internal server error"},
	}
)

// Validation creates a validation error with a custom message.
func Validation(message string) HTTPError {
	return HTTPError{
		StatusCode: http.StatusUnprocessableEntity,
		Response:   Response{Error: "validation_error", Message: message},
	}
}

// BadRequest creates a bad request error with a custom message.
func BadRequest(message string) HTTPError {
	return HTTPError{
		StatusCode: http.StatusBadRequest,
		Response:   Response{Error: "bad_request", Message: message},
	}
}

// MapDomainError maps domain errors to HTTP errors with appropriate status codes.
// It returns the HTTP status code, error code, and user-facing message.
func MapDomainError(err error) (int, string, string) {
	switch {
	case errors.Is(err, domain.ErrValidation):
		return http.StatusUnprocessableEntity, "validation_error", err.Error()
	case errors.Is(err, domain.ErrEmailAlreadyUsed):
		return http.StatusConflict, "email_taken", "email already used"
	case errors.Is(err, domain.ErrInvalidCreds):
		return http.StatusUnauthorized, "invalid_credentials", "invalid email or password"
	case errors.Is(err, domain.ErrUnauthorized):
		return http.StatusUnauthorized, "unauthorized", "unauthorized"
	case errors.Is(err, domain.ErrForbidden):
		return http.StatusForbidden, "forbidden", "forbidden"
	case errors.Is(err, domain.ErrTooManyRequests):
		return http.StatusTooManyRequests, "rate_limited", "too many requests"
	case errors.Is(err, domain.ErrNotFound):
		return http.StatusNotFound, "not_found", "resource not found"
	case errors.Is(err, domain.ErrTelegramDisabled):
		return http.StatusServiceUnavailable, "telegram_disabled", "telegram login is not configured on the server"
	case errors.Is(err, domain.ErrGoogleDisabled):
		return http.StatusServiceUnavailable, "google_disabled", "google login is not configured on the server"
	case errors.Is(err, domain.ErrAlreadyMember):
		return http.StatusConflict, "already_member", "user is already a member of this organization"
	case errors.Is(err, domain.ErrOwnerCannotLeave):
		return http.StatusConflict, "owner_cannot_leave", "owner must transfer ownership or delete the organization"
	case errors.Is(err, domain.ErrCannotDeletePersonalOrg):
		return http.StatusConflict, "personal_org_protected", "personal organization cannot be deleted"
	case errors.Is(err, domain.ErrInviteNotUsable):
		return http.StatusConflict, "invite_not_usable", "invite is no longer usable"
	case errors.Is(err, domain.ErrInviteWrongOrg):
		return http.StatusConflict, "invite_wrong_org", "invite belongs to a different organization"
	case errors.Is(err, domain.ErrCannotTargetOwner):
		return http.StatusConflict, "cannot_target_owner", "cannot modify organization owner"
	case errors.Is(err, domain.ErrCannotTargetSelf):
		return http.StatusConflict, "cannot_target_self", "cannot perform this action on self"
	case errors.Is(err, domain.ErrConflict):
		return http.StatusConflict, "conflict", "conflict"
	case errors.Is(err, infrajwt.ErrInvalidToken):
		return http.StatusUnauthorized, "invalid_access_token", "invalid access token"
	default:
		return http.StatusInternalServerError, "internal_error", "internal server error"
	}
}

// ShouldLog returns true if the error should be logged (5xx errors).
func ShouldLog(statusCode int) bool {
	return statusCode >= 500
}

// LogError logs an error with context if it's a server error (5xx).
func LogError(statusCode int, err error, path string) {
	if ShouldLog(statusCode) {
		slog.Error("request failed", "err", err, "path", path, "status", statusCode)
	}
}
