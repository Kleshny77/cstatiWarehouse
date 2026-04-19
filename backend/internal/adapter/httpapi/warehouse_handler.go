package httpapi

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type WarehouseHandler struct {
	warehouse *usecase.WarehouseUseCase
}

func NewWarehouseHandler(warehouse *usecase.WarehouseUseCase) *WarehouseHandler {
	return &WarehouseHandler{warehouse: warehouse}
}

type itemDTO struct {
	ID             string     `json:"id"`
	Name           string     `json:"name"`
	Description    string     `json:"description"`
	CategoryName   string     `json:"category_name"`
	Quantity       int        `json:"quantity"`
	Status         string     `json:"status"`
	ArchiveReason  *string    `json:"archive_reason,omitempty"`
	ArchivedAt     *time.Time `json:"archived_at,omitempty"`
	ExpirationDate *time.Time `json:"expiration_date,omitempty"`
	ImageURL       *string    `json:"image_url,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

func itemToDTO(i *domain.Item) itemDTO {
	dto := itemDTO{
		ID:             i.ID.String(),
		Name:           i.Name,
		Description:    i.Description,
		CategoryName:   i.CategoryName,
		Quantity:       i.Quantity,
		Status:         string(i.Status),
		ArchivedAt:     i.ArchivedAt,
		ExpirationDate: i.ExpirationDate,
		ImageURL:       i.ImageURL,
		CreatedAt:      i.CreatedAt,
		UpdatedAt:      i.UpdatedAt,
	}
	if i.ArchiveReason != nil {
		s := string(*i.ArchiveReason)
		dto.ArchiveReason = &s
	}
	return dto
}

type itemListResponse struct {
	Items []itemDTO `json:"items"`
}

type itemResponse struct {
	Item itemDTO `json:"item"`
}

type categoriesResponse struct {
	Categories []string `json:"categories"`
}

type createItemRequest struct {
	Name           string     `json:"name"`
	Description    string     `json:"description"`
	CategoryName   string     `json:"category_name"`
	Quantity       int        `json:"quantity"`
	ExpirationDate *time.Time `json:"expiration_date,omitempty"`
	ImageURL       *string    `json:"image_url,omitempty"`
}

type updateItemRequest = createItemRequest

type archiveRequest struct {
	Quantity     int    `json:"quantity"`
	Reason       string `json:"reason"`
	ReasonDetail string `json:"reason_detail,omitempty"`
}

type archiveEventDTO struct {
	ID           string    `json:"id"`
	ItemID       string    `json:"item_id"`
	Quantity     int       `json:"quantity"`
	Reason       string    `json:"reason"`
	ReasonDetail string    `json:"reason_detail,omitempty"`
	ArchivedAt   time.Time `json:"archived_at"`
}

type archiveEventsResponse struct {
	Events []archiveEventDTO `json:"events"`
}

type archiveResponse struct {
	Item  itemDTO         `json:"item"`
	Event archiveEventDTO `json:"event"`
}

func (h *WarehouseHandler) List(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	filter := usecase.ItemFilter{}
	switch r.URL.Query().Get("status") {
	case "":
	case string(domain.ItemStatusInStock):
		s := domain.ItemStatusInStock
		filter.Status = &s
	case string(domain.ItemStatusArchived):
		s := domain.ItemStatusArchived
		filter.Status = &s
	default:
		writeError(w, r, domain.NewValidationError("invalid status filter"))
		return
	}

	items, err := h.warehouse.List(r.Context(), ownerID, filter)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]itemDTO, 0, len(items))
	for i := range items {
		dtos = append(dtos, itemToDTO(&items[i]))
	}
	writeJSON(w, http.StatusOK, itemListResponse{Items: dtos})
}

func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req createItemRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	item, err := h.warehouse.Create(r.Context(), usecase.CreateItemInput{
		OwnerID: ownerID, Name: req.Name, Description: req.Description,
		CategoryName: req.CategoryName, Quantity: req.Quantity,
		ExpirationDate: req.ExpirationDate, ImageURL: req.ImageURL,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, itemResponse{Item: itemToDTO(item)})
}

func (h *WarehouseHandler) Update(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req updateItemRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	item, err := h.warehouse.Update(r.Context(), usecase.UpdateItemInput{
		ID: id, OwnerID: ownerID, Name: req.Name, Description: req.Description,
		CategoryName: req.CategoryName, Quantity: req.Quantity,
		ExpirationDate: req.ExpirationDate, ImageURL: req.ImageURL,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, itemResponse{Item: itemToDTO(item)})
}

func (h *WarehouseHandler) Archive(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req archiveRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	quantity := req.Quantity
	if quantity == 0 {
		quantity = 1
	}
	item, event, err := h.warehouse.Archive(r.Context(), usecase.ArchiveItemInput{
		ItemID:       id,
		OwnerID:      ownerID,
		Quantity:     quantity,
		Reason:       domain.ArchiveReason(req.Reason),
		ReasonDetail: req.ReasonDetail,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, archiveResponse{Item: itemToDTO(item), Event: archiveEventToDTO(event)})
}

// ArchiveEvents — GET /archive-events: история списаний пользователя.
func (h *WarehouseHandler) ArchiveEvents(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	events, err := h.warehouse.ListArchiveEvents(r.Context(), ownerID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]archiveEventDTO, 0, len(events))
	for i := range events {
		dtos = append(dtos, archiveEventToDTO(&events[i]))
	}
	writeJSON(w, http.StatusOK, archiveEventsResponse{Events: dtos})
}

func archiveEventToDTO(e *domain.ArchiveEvent) archiveEventDTO {
	return archiveEventDTO{
		ID:           e.ID.String(),
		ItemID:       e.ItemID.String(),
		Quantity:     e.Quantity,
		Reason:       string(e.Reason),
		ReasonDetail: e.ReasonDetail,
		ArchivedAt:   e.ArchivedAt,
	}
}

func (h *WarehouseHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	id, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	if err := h.warehouse.Delete(r.Context(), id, ownerID); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *WarehouseHandler) Categories(w http.ResponseWriter, r *http.Request) {
	ownerID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	cats, err := h.warehouse.Categories(r.Context(), ownerID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	if cats == nil {
		cats = []string{}
	}
	writeJSON(w, http.StatusOK, categoriesResponse{Categories: cats})
}

func parseIDPath(r *http.Request, name string) (uuid.UUID, error) {
	raw := r.PathValue(name)
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, domain.NewValidationError("invalid " + name)
	}
	return id, nil
}
