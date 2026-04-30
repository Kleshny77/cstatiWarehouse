package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ExpirationNotificationsHandler struct {
	uc *usecase.ExpirationNotificationsUseCase
}

func NewExpirationNotificationsHandler(uc *usecase.ExpirationNotificationsUseCase) *ExpirationNotificationsHandler {
	return &ExpirationNotificationsHandler{uc: uc}
}

type notificationPreferencesDTO struct {
	UserID                string `json:"user_id"`
	EarlyWarningEnabled   bool   `json:"early_warning_enabled"`
	ActionRequiredEnabled bool   `json:"action_required_enabled"`
	CriticalEnabled       bool   `json:"critical_enabled"`
	ExpiredEnabled        bool   `json:"expired_enabled"`
	QuietHoursStartMinute int    `json:"quiet_hours_start_minute"`
	QuietHoursEndMinute   int    `json:"quiet_hours_end_minute"`
	Timezone              string `json:"timezone"`
	UpdatedAt             string `json:"updated_at"`
}

func toPreferencesDTO(p domain.UserNotificationPreferences) notificationPreferencesDTO {
	return notificationPreferencesDTO{
		UserID:                p.UserID.String(),
		EarlyWarningEnabled:   p.EarlyWarningEnabled,
		ActionRequiredEnabled: p.ActionRequiredEnabled,
		CriticalEnabled:       p.CriticalEnabled,
		ExpiredEnabled:        p.ExpiredEnabled,
		QuietHoursStartMinute: p.QuietHoursStartMinute,
		QuietHoursEndMinute:   p.QuietHoursEndMinute,
		Timezone:              p.Timezone,
		UpdatedAt:             p.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func (h *ExpirationNotificationsHandler) GetPreferences(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	p, err := h.uc.GetPreferences(r.Context(), userID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toPreferencesDTO(p))
}

type updatePreferencesBody struct {
	EarlyWarningEnabled   *bool   `json:"early_warning_enabled"`
	ActionRequiredEnabled *bool   `json:"action_required_enabled"`
	CriticalEnabled       *bool   `json:"critical_enabled"`
	ExpiredEnabled        *bool   `json:"expired_enabled"`
	QuietHoursStartMinute *int    `json:"quiet_hours_start_minute"`
	QuietHoursEndMinute   *int    `json:"quiet_hours_end_minute"`
	Timezone              *string `json:"timezone"`
}

func (h *ExpirationNotificationsHandler) UpdatePreferences(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var body updatePreferencesBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	updated, err := h.uc.UpdatePreferences(r.Context(), usecase.UpdatePreferencesInput{
		UserID:                userID,
		EarlyWarningEnabled:   body.EarlyWarningEnabled,
		ActionRequiredEnabled: body.ActionRequiredEnabled,
		CriticalEnabled:       body.CriticalEnabled,
		ExpiredEnabled:        body.ExpiredEnabled,
		QuietHoursStartMinute: body.QuietHoursStartMinute,
		QuietHoursEndMinute:   body.QuietHoursEndMinute,
		Timezone:              body.Timezone,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toPreferencesDTO(updated))
}

type expirationNotificationDTO struct {
	ID             string  `json:"id"`
	ItemID         string  `json:"item_id"`
	OrganizationID string  `json:"organization_id"`
	Level          string  `json:"level"`
	SentAt         string  `json:"sent_at"`
	DeliveryStatus string  `json:"delivery_status"`
	SnoozeUntil    *string `json:"snooze_until,omitempty"`
}

func (h *ExpirationNotificationsHandler) ListRecent(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 {
			limit = n
		}
	}
	items, err := h.uc.ListRecent(r.Context(), userID, limit)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out := make([]expirationNotificationDTO, len(items))
	for i, n := range items {
		dto := expirationNotificationDTO{
			ID:             n.ID.String(),
			ItemID:         n.ItemID.String(),
			OrganizationID: n.OrganizationID.String(),
			Level:          string(n.Level),
			SentAt:         n.SentAt.UTC().Format(time.RFC3339),
			DeliveryStatus: string(n.DeliveryStatus),
		}
		if n.SnoozeUntil != nil {
			s := n.SnoozeUntil.UTC().Format(time.RFC3339)
			dto.SnoozeUntil = &s
		}
		out[i] = dto
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type snoozeBody struct {
	ItemID   string `json:"item_id"`
	Duration string `json:"duration"`
}

func (h *ExpirationNotificationsHandler) Snooze(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var body snoozeBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	itemID, err := uuid.Parse(body.ItemID)
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid item_id"))
		return
	}
	dur, err := time.ParseDuration(body.Duration)
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid duration"))
		return
	}
	if err := h.uc.SnoozeItem(r.Context(), userID, itemID, dur); err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
