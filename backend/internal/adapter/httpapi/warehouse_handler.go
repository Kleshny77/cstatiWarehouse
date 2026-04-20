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
	ID              string     `json:"id"`
	OrganizationID  string     `json:"organization_id"`
	HeldByUserID    string     `json:"held_by_user_id"`
	Name            string     `json:"name"`
	Description     string     `json:"description"`
	CategoryName    string     `json:"category_name"`
	Quantity        int        `json:"quantity"`
	Status          string     `json:"status"`
	ArchiveReason   *string    `json:"archive_reason,omitempty"`
	ArchivedAt      *time.Time `json:"archived_at,omitempty"`
	ExpirationDate  *time.Time `json:"expiration_date,omitempty"`
	ImageURL        *string    `json:"image_url,omitempty"`
	LocationAddress *string    `json:"location_address,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

func itemToDTO(i *domain.Item) itemDTO {
	dto := itemDTO{
		ID:              i.ID.String(),
		OrganizationID:  i.OrganizationID.String(),
		HeldByUserID:    i.HeldByUserID.String(),
		Name:            i.Name,
		Description:     i.Description,
		CategoryName:    i.CategoryName,
		Quantity:        i.Quantity,
		Status:          string(i.Status),
		ArchivedAt:      i.ArchivedAt,
		ExpirationDate:  i.ExpirationDate,
		ImageURL:        i.ImageURL,
		LocationAddress: i.LocationAddress,
		CreatedAt:       i.CreatedAt,
		UpdatedAt:       i.UpdatedAt,
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
	OrganizationID  string     `json:"organization_id"`
	HeldByUserID    *string    `json:"held_by_user_id,omitempty"`
	Name            string     `json:"name"`
	Description     string     `json:"description"`
	CategoryName    string     `json:"category_name"`
	Quantity        int        `json:"quantity"`
	ExpirationDate  *time.Time `json:"expiration_date,omitempty"`
	ImageURL        *string    `json:"image_url,omitempty"`
	LocationAddress *string    `json:"location_address,omitempty"`
}

type updateItemRequest struct {
	HeldByUserID    *string    `json:"held_by_user_id,omitempty"`
	Name            string     `json:"name"`
	Description     string     `json:"description"`
	CategoryName    string     `json:"category_name"`
	Quantity        int        `json:"quantity"`
	ExpirationDate  *time.Time `json:"expiration_date,omitempty"`
	ImageURL        *string    `json:"image_url,omitempty"`
	LocationAddress *string    `json:"location_address,omitempty"`
}

type archiveRequest struct {
	Quantity     int     `json:"quantity"`
	Reason       string  `json:"reason"`
	ReasonDetail string  `json:"reason_detail,omitempty"`
	EventID      *string `json:"event_id,omitempty"`
}

type archiveEventDTO struct {
	ID                 string    `json:"id"`
	ItemID             string    `json:"item_id"`
	OrganizationID     string    `json:"organization_id"`
	ArchivedByUserID   string    `json:"archived_by_user_id"`
	ItemName           string    `json:"item_name"`
	ArchivedByName     string    `json:"archived_by_name"`
	Quantity           int       `json:"quantity"`
	Reason             string    `json:"reason"`
	ReasonDetail       string    `json:"reason_detail,omitempty"`
	EventID            *string   `json:"event_id,omitempty"`
	ArchivedAt         time.Time `json:"archived_at"`
}

type archiveEventsResponse struct {
	Events []archiveEventDTO `json:"events"`
}

type archiveResponse struct {
	Item  itemDTO         `json:"item"`
	Event archiveEventDTO `json:"event"`
}

func (h *WarehouseHandler) List(w http.ResponseWriter, r *http.Request) {
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

	// scope: "mine" (по умолчанию) ограничивает выдачу позициями, за которые отвечает
	// текущий пользователь. "all" доступен только админам/владельцу (проверяется в usecase).
	switch r.URL.Query().Get("scope") {
	case "", "mine":
		uid := userID
		filter.HeldByUserID = &uid
	case "all":
		// не навязываем фильтр — usecase сам решит, имеет ли пользователь право.
	default:
		writeError(w, r, domain.NewValidationError("invalid scope filter"))
		return
	}

	items, err := h.warehouse.List(r.Context(), userID, orgID, filter)
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
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req createItemRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	orgID, err := parseRequiredUUID(req.OrganizationID, "organization_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	heldBy, err := parseOptionalUUID(req.HeldByUserID, "held_by_user_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	item, err := h.warehouse.Create(r.Context(), usecase.CreateItemInput{
		UserID:          userID,
		OrganizationID:  orgID,
		HeldByUserID:    heldBy,
		Name:            req.Name,
		Description:     req.Description,
		CategoryName:    req.CategoryName,
		Quantity:        req.Quantity,
		ExpirationDate:  req.ExpirationDate,
		ImageURL:        req.ImageURL,
		LocationAddress: req.LocationAddress,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, itemResponse{Item: itemToDTO(item)})
}

func (h *WarehouseHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var req updateItemRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	heldBy, err := parseOptionalUUID(req.HeldByUserID, "held_by_user_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	item, err := h.warehouse.Update(r.Context(), usecase.UpdateItemInput{
		ID:              id,
		UserID:          userID,
		HeldByUserID:    heldBy,
		Name:            req.Name,
		Description:     req.Description,
		CategoryName:    req.CategoryName,
		Quantity:        req.Quantity,
		ExpirationDate:  req.ExpirationDate,
		ImageURL:        req.ImageURL,
		LocationAddress: req.LocationAddress,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, itemResponse{Item: itemToDTO(item)})
}

func (h *WarehouseHandler) Archive(w http.ResponseWriter, r *http.Request) {
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
	var req archiveRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	quantity := req.Quantity
	if quantity == 0 {
		quantity = 1
	}
	eventID, err := parseOptionalUUID(req.EventID, "event_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	item, event, err := h.warehouse.Archive(r.Context(), usecase.ArchiveItemInput{
		ItemID:       id,
		UserID:       userID,
		Quantity:     quantity,
		Reason:       domain.ArchiveReason(req.Reason),
		ReasonDetail: req.ReasonDetail,
		EventID:      eventID,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, archiveResponse{Item: itemToDTO(item), Event: archiveEventToDTO(event)})
}

// ArchiveEvents — GET /archive-events?organizationId=...: история списаний в организации.
func (h *WarehouseHandler) ArchiveEvents(w http.ResponseWriter, r *http.Request) {
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
	events, err := h.warehouse.ListArchiveEvents(r.Context(), userID, orgID)
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
	dto := archiveEventDTO{
		ID:                 e.ID.String(),
		ItemID:             e.ItemID.String(),
		OrganizationID:     e.OrganizationID.String(),
		ArchivedByUserID:   e.ArchivedByUserID.String(),
		ItemName:           e.ItemName,
		ArchivedByName:     e.ArchivedByDisplayName,
		Quantity:           e.Quantity,
		Reason:             string(e.Reason),
		ReasonDetail:       e.ReasonDetail,
		ArchivedAt:         e.ArchivedAt,
	}
	if e.EventID != nil {
		s := e.EventID.String()
		dto.EventID = &s
	}
	return dto
}

func (h *WarehouseHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
	if err := h.warehouse.Delete(r.Context(), id, userID); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *WarehouseHandler) Categories(w http.ResponseWriter, r *http.Request) {
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
	cats, err := h.warehouse.Categories(r.Context(), userID, orgID)
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

// requireOrganizationID извлекает обязательный query-параметр organizationId.
func requireOrganizationID(r *http.Request) (uuid.UUID, error) {
	raw := r.URL.Query().Get("organizationId")
	if raw == "" {
		return uuid.Nil, domain.NewValidationError("organizationId query parameter is required")
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, domain.NewValidationError("invalid organizationId")
	}
	return id, nil
}

func parseRequiredUUID(raw, name string) (uuid.UUID, error) {
	if raw == "" {
		return uuid.Nil, domain.NewValidationError(name + " is required")
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, domain.NewValidationError("invalid " + name)
	}
	return id, nil
}

func parseOptionalUUID(raw *string, name string) (*uuid.UUID, error) {
	if raw == nil || *raw == "" {
		return nil, nil
	}
	id, err := uuid.Parse(*raw)
	if err != nil {
		return nil, domain.NewValidationError("invalid " + name)
	}
	return &id, nil
}
