package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/pkg/apierror"
)

type NotificationsHandler struct {
	repo *repo.DevicePushTokenRepo
	now  func() time.Time
}

func NewNotificationsHandler(repo *repo.DevicePushTokenRepo) *NotificationsHandler {
	return &NotificationsHandler{repo: repo, now: time.Now}
}

type registerAPNsBody struct {
	Token string `json:"token"`
}

func (h *NotificationsHandler) RegisterAPNs(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var body registerAPNsBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeHTTPError(w, apierror.BadJSON)
		return
	}
	token := strings.TrimSpace(body.Token)
	if len(token) < 16 || len(token) > 2048 {
		writeHTTPError(w, apierror.Validation("invalid token"))
		return
	}
	if err := h.repo.UpsertAPNs(r.Context(), userID, token, h.now()); err != nil {
		slog.ErrorContext(r.Context(), "apns token upsert", "err", err)
		writeHTTPError(w, apierror.InternalError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
