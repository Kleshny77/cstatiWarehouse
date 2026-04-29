package httpapi

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	infrajwt "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"
)

type errorBody struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if body == nil {
		return
	}
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, r *http.Request, err error) {
	status, code, message := mapError(err)
	if status >= 500 {
		slog.ErrorContext(r.Context(), "request failed", "err", err, "path", r.URL.Path)
	}
	writeJSON(w, status, errorBody{Error: code, Message: message})
}

func mapError(err error) (int, string, string) {
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
