package httpapi

import (
	"errors"
	"net/http"
	"sort"
	"strconv"
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
	ID                     string     `json:"id"`
	OrganizationID         string     `json:"organization_id"`
	HeldByUserID           string     `json:"held_by_user_id"`
	Name                   string     `json:"name"`
	Description            string     `json:"description"`
	CategoryName           string     `json:"category_name"`
	Quantity               int        `json:"quantity"`
	Status                 string     `json:"status"`
	ArchiveReason          *string    `json:"archive_reason,omitempty"`
	ArchivedAt             *time.Time `json:"archived_at,omitempty"`
	ExpirationDate         *time.Time `json:"expiration_date,omitempty"`
	ImageURL               *string    `json:"image_url,omitempty"`
	LocationAddress        *string    `json:"location_address,omitempty"`
	ParentItemID           *string    `json:"parent_item_id,omitempty"`
	VariantLabel           string     `json:"variant_label,omitempty"`
	MeasureUnit            string     `json:"measure_unit"`
	VolumePerUnit          *float64   `json:"volume_per_unit,omitempty"`
	Variants               []itemDTO  `json:"variants,omitempty"`
	AggregatedVolumeLiters *float64   `json:"aggregated_volume_liters,omitempty"`
	CreatedAt              time.Time  `json:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at"`
}

func itemToDTO(i *domain.Item) itemDTO {
	mu := i.MeasureUnit
	if mu == "" {
		mu = domain.MeasureUnitPiece
	}
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
		ParentItemID:    uuidPtrToJSON(i.ParentItemID),
		VariantLabel:    i.VariantLabel,
		MeasureUnit:     string(mu),
		VolumePerUnit:   i.VolumePerUnit,
		CreatedAt:       i.CreatedAt,
		UpdatedAt:       i.UpdatedAt,
	}
	if i.ArchiveReason != nil {
		s := string(*i.ArchiveReason)
		dto.ArchiveReason = &s
	}
	return dto
}

func uuidPtrToJSON(id *uuid.UUID) *string {
	if id == nil {
		return nil
	}
	s := id.String()
	return &s
}

func itemToNestedDTO(root *domain.Item, variants []domain.Item) itemDTO {
	dto := itemToDTO(root)
	if len(variants) == 0 {
		return dto
	}
	dto.Variants = make([]itemDTO, 0, len(variants))
	var sum float64
	var hasLiters bool
	for i := range variants {
		v := &variants[i]
		dto.Variants = append(dto.Variants, itemToDTO(v))
		if v.Status != domain.ItemStatusInStock {
			continue
		}
		switch v.MeasureUnit {
		case domain.MeasureUnitLiter:
			sum += float64(v.Quantity) * domain.EffectiveAmountPerUnit(v.VolumePerUnit)
			hasLiters = true
		case domain.MeasureUnitMilliliter:
			sum += float64(v.Quantity) * domain.EffectiveAmountPerUnit(v.VolumePerUnit) / 1000.0
			hasLiters = true
		default:
		}
	}
	if hasLiters {
		dto.AggregatedVolumeLiters = &sum
	}
	return dto
}

func buildNestedItemDTOs(flat []domain.Item) []itemDTO {
	byParent := make(map[uuid.UUID][]domain.Item)
	var roots []domain.Item
	for i := range flat {
		it := flat[i]
		if it.ParentItemID != nil {
			pid := *it.ParentItemID
			byParent[pid] = append(byParent[pid], it)
		} else {
			roots = append(roots, it)
		}
	}
	sort.Slice(roots, func(i, j int) bool {
		return roots[i].CreatedAt.After(roots[j].CreatedAt)
	})
	out := make([]itemDTO, 0, len(roots))
	for i := range roots {
		ch := byParent[roots[i].ID]
		sort.Slice(ch, func(a, b int) bool {
			return ch[a].CreatedAt.After(ch[b].CreatedAt)
		})
		out = append(out, itemToNestedDTO(&roots[i], ch))
	}
	return out
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
	ParentItemID    *string    `json:"parent_item_id,omitempty"`
	VariantLabel    string     `json:"variant_label"`
	MeasureUnit     string     `json:"measure_unit"`
	VolumePerUnit   *float64   `json:"volume_per_unit,omitempty"`
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
	VariantLabel    string     `json:"variant_label"`
	MeasureUnit     string     `json:"measure_unit"`
	VolumePerUnit   *float64   `json:"volume_per_unit,omitempty"`
	// ExpectedUpdatedAt при optimistic locking: клиент передаёт updated_at с момента открытия формы.
	ExpectedUpdatedAt *time.Time `json:"expected_updated_at,omitempty"`
}

type itemVersionConflictResponse struct {
	Error   string  `json:"error"`
	Message string  `json:"message"`
	Item    itemDTO `json:"item"`
}

type archiveRequest struct {
	Quantity     int     `json:"quantity"`
	Reason       string  `json:"reason"`
	ReasonDetail string  `json:"reason_detail,omitempty"`
	EventID      *string `json:"event_id,omitempty"`
}

type archiveEventDTO struct {
	ID               string    `json:"id"`
	ItemID           string    `json:"item_id"`
	OrganizationID   string    `json:"organization_id"`
	ArchivedByUserID string    `json:"archived_by_user_id"`
	ItemName         string    `json:"item_name"`
	ArchivedByName   string    `json:"archived_by_name"`
	Quantity         int       `json:"quantity"`
	Reason           string    `json:"reason"`
	ReasonDetail     string    `json:"reason_detail,omitempty"`
	EventID          *string   `json:"event_id,omitempty"`
	ArchivedAt       time.Time `json:"archived_at"`
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

	switch r.URL.Query().Get("scope") {
	case "", "mine":
		uid := userID
		filter.HeldByUserID = &uid
	case "all":
	default:
		writeError(w, r, domain.NewValidationError("invalid scope filter"))
		return
	}

	items, err := h.warehouse.List(r.Context(), userID, orgID, filter)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, itemListResponse{Items: buildNestedItemDTOs(items)})
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
	parentID, err := parseOptionalUUID(req.ParentItemID, "parent_item_id")
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
		ParentItemID:    parentID,
		VariantLabel:    req.VariantLabel,
		MeasureUnit:     req.MeasureUnit,
		VolumePerUnit:   req.VolumePerUnit,
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
		ID:                id,
		UserID:            userID,
		HeldByUserID:      heldBy,
		Name:              req.Name,
		Description:       req.Description,
		CategoryName:      req.CategoryName,
		Quantity:          req.Quantity,
		ExpirationDate:    req.ExpirationDate,
		ImageURL:          req.ImageURL,
		LocationAddress:   req.LocationAddress,
		VariantLabel:      req.VariantLabel,
		MeasureUnit:       req.MeasureUnit,
		VolumePerUnit:     req.VolumePerUnit,
		ExpectedUpdatedAt: req.ExpectedUpdatedAt,
	})
	if err != nil {
		var conflict *domain.ItemVersionConflictError
		if errors.As(err, &conflict) {
			writeJSON(w, http.StatusConflict, itemVersionConflictResponse{
				Error:   "item_version_conflict",
				Message: "Позиция уже изменена на сервере или с другого устройства",
				Item:    itemToDTO(&conflict.ServerItem),
			})
			return
		}
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

	// Parse pagination parameters
	limit := 50 // default
	offset := 0
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 && parsedLimit <= 100 {
			limit = parsedLimit
		}
	}
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	events, err := h.warehouse.ListArchiveEvents(r.Context(), userID, orgID, limit, offset)
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
		ID:               e.ID.String(),
		ItemID:           e.ItemID.String(),
		OrganizationID:   e.OrganizationID.String(),
		ArchivedByUserID: e.ArchivedByUserID.String(),
		ItemName:         e.ItemName,
		ArchivedByName:   e.ArchivedByDisplayName,
		Quantity:         e.Quantity,
		Reason:           string(e.Reason),
		ReasonDetail:     e.ReasonDetail,
		ArchivedAt:       e.ArchivedAt,
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
