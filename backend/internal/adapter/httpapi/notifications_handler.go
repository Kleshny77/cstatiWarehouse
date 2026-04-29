package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/adapter/repo"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
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
		writeJSON(w, http.StatusBadRequest, errorBody{Error: "bad_json", Message: "invalid body"})
		return
	}
	token := strings.TrimSpace(body.Token)
	if len(token) < 16 || len(token) > 2048 {
		writeJSON(w, http.StatusBadRequest, errorBody{Error: "validation", Message: "invalid token"})
		return
	}
	if err := h.repo.UpsertAPNs(r.Context(), userID, token, h.now()); err != nil {
		slog.ErrorContext(r.Context(), "apns token upsert", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorBody{Error: "internal_error", Message: "could not save"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
