//
// activity_handler.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package httpapi

import (
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ActivityHandler struct {
	activity *usecase.ActivityUseCase
}

func NewActivityHandler(activity *usecase.ActivityUseCase) *ActivityHandler {
	return &ActivityHandler{activity: activity}
}

type activityDTO struct {
	ID             string    `json:"id"`
	OrganizationID string    `json:"organization_id"`
	ActorUserID    string    `json:"actor_user_id"`
	ActorName      string    `json:"actor_name"`
	Kind           string    `json:"kind"`
	TargetType     string    `json:"target_type,omitempty"`
	TargetID       *string   `json:"target_id,omitempty"`
	Summary        string    `json:"summary"`
	CreatedAt      time.Time `json:"created_at"`
}

type activityListResponse struct {
	Entries []activityDTO `json:"entries"`
}

func activityToDTO(e *domain.ActivityEntry) activityDTO {
	dto := activityDTO{
		ID:             e.ID.String(),
		OrganizationID: e.OrganizationID.String(),
		ActorUserID:    e.ActorUserID.String(),
		ActorName:      e.ActorDisplayName,
		Kind:           string(e.Kind),
		TargetType:     e.TargetType,
		Summary:        e.Summary,
		CreatedAt:      e.CreatedAt,
	}
	if e.TargetID != nil {
		s := e.TargetID.String()
		dto.TargetID = &s
	}
	return dto
}

func (h *ActivityHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	limit := parseLimit(r, 100, 500)
	entries, err := h.activity.List(r.Context(), userID, orgID, limit)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]activityDTO, 0, len(entries))
	for i := range entries {
		dtos = append(dtos, activityToDTO(&entries[i]))
	}
	writeJSON(w, http.StatusOK, activityListResponse{Entries: dtos})
}
