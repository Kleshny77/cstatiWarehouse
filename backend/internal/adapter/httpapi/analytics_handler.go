//
// analytics_handler.go
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

package httpapi

import (
	"net/http"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
	"github.com/google/uuid"
)

type AnalyticsHandler struct {
	uc *usecase.AnalyticsUseCase
}

func NewAnalyticsHandler(uc *usecase.AnalyticsUseCase) *AnalyticsHandler {
	return &AnalyticsHandler{uc: uc}
}

func (h *AnalyticsHandler) GetDashboard(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	orgIDStr := r.URL.Query().Get("organization_id")
	if orgIDStr == "" {
		writeError(w, r, domain.NewValidationError("organization_id is required"))
		return
	}

	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid organization_id format"))
		return
	}

	metrics, err := h.uc.GetDashboardMetrics(r.Context(), userID, orgID)
	if err != nil {
		writeError(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, metrics)
}
