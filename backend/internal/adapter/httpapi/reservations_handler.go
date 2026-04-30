package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type ReservationsHandler struct {
	uc *usecase.ReservationsUseCase
}

func NewReservationsHandler(uc *usecase.ReservationsUseCase) *ReservationsHandler {
	return &ReservationsHandler{uc: uc}
}

type reservationDTO struct {
	ID                 string  `json:"id"`
	ItemID             string  `json:"item_id"`
	OrganizationID     string  `json:"organization_id"`
	Quantity           int     `json:"quantity"`
	EventID            *string `json:"event_id,omitempty"`
	ReservedByUserID   string  `json:"reserved_by_user_id"`
	ReservedAt         string  `json:"reserved_at"`
	ExpiresAt          *string `json:"expires_at,omitempty"`
	Status             string  `json:"status"`
	FulfilledAt        *string `json:"fulfilled_at,omitempty"`
	FulfilledByUserID  *string `json:"fulfilled_by_user_id,omitempty"`
	CancelledAt        *string `json:"cancelled_at,omitempty"`
	CancelledByUserID  *string `json:"cancelled_by_user_id,omitempty"`
	CancellationReason string  `json:"cancellation_reason"`
	Notes              string  `json:"notes"`
	CreatedAt          string  `json:"created_at"`
	UpdatedAt          string  `json:"updated_at"`
}

func toReservationDTO(r domain.ItemReservation) reservationDTO {
	dto := reservationDTO{
		ID:                 r.ID.String(),
		ItemID:             r.ItemID.String(),
		OrganizationID:     r.OrganizationID.String(),
		Quantity:           r.Quantity,
		ReservedByUserID:   r.ReservedByUserID.String(),
		ReservedAt:         r.ReservedAt.UTC().Format(time.RFC3339),
		Status:             string(r.Status),
		CancellationReason: r.CancellationReason,
		Notes:              r.Notes,
		CreatedAt:          r.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:          r.UpdatedAt.UTC().Format(time.RFC3339),
	}
	if r.EventID != nil {
		s := r.EventID.String()
		dto.EventID = &s
	}
	if r.ExpiresAt != nil {
		s := r.ExpiresAt.UTC().Format(time.RFC3339)
		dto.ExpiresAt = &s
	}
	if r.FulfilledAt != nil {
		s := r.FulfilledAt.UTC().Format(time.RFC3339)
		dto.FulfilledAt = &s
	}
	if r.FulfilledByUserID != nil {
		s := r.FulfilledByUserID.String()
		dto.FulfilledByUserID = &s
	}
	if r.CancelledAt != nil {
		s := r.CancelledAt.UTC().Format(time.RFC3339)
		dto.CancelledAt = &s
	}
	if r.CancelledByUserID != nil {
		s := r.CancelledByUserID.String()
		dto.CancelledByUserID = &s
	}
	return dto
}

type createReservationBody struct {
	Quantity  int     `json:"quantity"`
	EventID   *string `json:"event_id"`
	ExpiresAt *string `json:"expires_at"`
	Notes     string  `json:"notes"`
}

func (h *ReservationsHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	itemID, err := uuid.Parse(r.PathValue("itemID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid item_id"))
		return
	}
	var body createReservationBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	var expiresAt *time.Time
	if body.ExpiresAt != nil && *body.ExpiresAt != "" {
		t, err := time.Parse(time.RFC3339, *body.ExpiresAt)
		if err != nil {
			writeError(w, r, domain.NewValidationError("invalid expires_at format"))
			return
		}
		expiresAt = &t
	}
	var eventID *uuid.UUID
	if body.EventID != nil && *body.EventID != "" {
		eid, err := uuid.Parse(*body.EventID)
		if err != nil {
			writeError(w, r, domain.NewValidationError("invalid event_id"))
			return
		}
		eventID = &eid
	}
	res, err := h.uc.Create(r.Context(), usecase.CreateReservationInput{
		ActorID:   userID,
		ItemID:    itemID,
		Quantity:  body.Quantity,
		EventID:   eventID,
		ExpiresAt: expiresAt,
		Notes:     body.Notes,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toReservationDTO(*res))
}

func (h *ReservationsHandler) ListByItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	itemID, err := uuid.Parse(r.PathValue("itemID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid item_id"))
		return
	}
	statusFilter, err := parseReservationStatus(r.URL.Query().Get("status"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	items, err := h.uc.ListByItem(r.Context(), userID, itemID, statusFilter)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out := make([]reservationDTO, len(items))
	for i, it := range items {
		out[i] = toReservationDTO(it)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (h *ReservationsHandler) ListByOrganization(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := uuid.Parse(r.PathValue("orgID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid organization_id"))
		return
	}
	statusFilter, err := parseReservationStatus(r.URL.Query().Get("status"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	items, err := h.uc.ListByOrganization(r.Context(), userID, orgID, statusFilter)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out := make([]reservationDTO, len(items))
	for i, it := range items {
		out[i] = toReservationDTO(it)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (h *ReservationsHandler) Availability(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	itemID, err := uuid.Parse(r.PathValue("itemID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid item_id"))
		return
	}
	total, reserved, available, err := h.uc.GetAvailableQuantity(r.Context(), userID, itemID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"item_id":   itemID.String(),
		"total":     total,
		"reserved":  reserved,
		"available": available,
	})
}

func (h *ReservationsHandler) Fulfill(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(r.PathValue("reservationID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid reservation_id"))
		return
	}
	res, err := h.uc.Fulfill(r.Context(), userID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toReservationDTO(*res))
}

type cancelReservationBody struct {
	CancellationReason string `json:"cancellation_reason"`
}

func (h *ReservationsHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(r.PathValue("reservationID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid reservation_id"))
		return
	}
	var body cancelReservationBody
	if r.ContentLength > 0 {
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, r, domain.NewValidationError("invalid json"))
			return
		}
	}
	res, err := h.uc.Cancel(r.Context(), usecase.CancelReservationInput{
		ActorID:            userID,
		ReservationID:      id,
		CancellationReason: body.CancellationReason,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toReservationDTO(*res))
}

func parseReservationStatus(raw string) (*domain.ReservationStatus, error) {
	if raw == "" {
		return nil, nil
	}
	s := domain.ReservationStatus(raw)
	if !s.IsValid() {
		return nil, domain.NewValidationError("invalid status filter")
	}
	return &s, nil
}
