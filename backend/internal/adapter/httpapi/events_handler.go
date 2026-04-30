//
// events_handler.go
// cstatiWarehouse
//
// Created by Артём on 20.04.2026.
//

package httpapi

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type EventsHandler struct {
	events *usecase.EventsUseCase
}

func NewEventsHandler(events *usecase.EventsUseCase) *EventsHandler {
	return &EventsHandler{events: events}
}

type eventDTO struct {
	ID             string     `json:"id"`
	OrganizationID string     `json:"organization_id"`
	CreatedByID    string     `json:"created_by_id"`
	Name           string     `json:"name"`
	Description    string     `json:"description"`
	StartsAt       *time.Time `json:"starts_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type eventsListResponse struct {
	Events []eventDTO `json:"events"`
}

type eventResponse struct {
	Event eventDTO `json:"event"`
}

type createEventRequest struct {
	OrganizationID string     `json:"organization_id"`
	Name           string     `json:"name"`
	Description    string     `json:"description"`
	StartsAt       *time.Time `json:"starts_at,omitempty"`
}

type updateEventRequest struct {
	Name        string     `json:"name"`
	Description string     `json:"description"`
	StartsAt    *time.Time `json:"starts_at,omitempty"`
}

func eventToDTO(e *domain.Event) eventDTO {
	return eventDTO{
		ID:             e.ID.String(),
		OrganizationID: e.OrganizationID.String(),
		CreatedByID:    e.CreatedByID.String(),
		Name:           e.Name,
		Description:    e.Description,
		StartsAt:       e.StartsAt,
		CreatedAt:      e.CreatedAt,
		UpdatedAt:      e.UpdatedAt,
	}
}

func (h *EventsHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := requireOrganizationID(r)
	if err != nil {
		writeError(w, r, err)
		return
	}
	events, err := h.events.List(r.Context(), userID, orgID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]eventDTO, 0, len(events))
	for i := range events {
		dtos = append(dtos, eventToDTO(&events[i]))
	}
	writeJSON(w, http.StatusOK, eventsListResponse{Events: dtos})
}

func (h *EventsHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req createEventRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	orgID, err := parseRequiredUUID(req.OrganizationID, "organization_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	event, err := h.events.Create(r.Context(), usecase.CreateEventInput{
		UserID:         userID,
		OrganizationID: orgID,
		Name:           req.Name,
		Description:    req.Description,
		StartsAt:       req.StartsAt,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, eventResponse{Event: eventToDTO(event)})
}

func (h *EventsHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req updateEventRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	event, err := h.events.Update(r.Context(), usecase.UpdateEventInput{
		ID:          id,
		UserID:      userID,
		Name:        req.Name,
		Description: req.Description,
		StartsAt:    req.StartsAt,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, eventResponse{Event: eventToDTO(event)})
}

func (h *EventsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	if err := h.events.Delete(r.Context(), userID, id); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func parseLimit(r *http.Request, defaultLimit, max int) int {
	raw := r.URL.Query().Get("limit")
	if raw == "" {
		return defaultLimit
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return defaultLimit
	}
	if n > max {
		return max
	}
	return n
}
