//
// categories_handler.go
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

type CategoriesHandler struct {
	categories *usecase.CategoriesUseCase
}

func NewCategoriesHandler(categories *usecase.CategoriesUseCase) *CategoriesHandler {
	return &CategoriesHandler{categories: categories}
}

type categoryDTO struct {
	ID             string    `json:"id"`
	OrganizationID string    `json:"organization_id"`
	CreatedByID    string    `json:"created_by_id"`
	Name           string    `json:"name"`
	CreatedAt      time.Time `json:"created_at"`
}

type categoryListResponse struct {
	Categories []categoryDTO `json:"categories"`
}

type categoryResponse struct {
	Category categoryDTO `json:"category"`
}

type createCategoryRequest struct {
	OrganizationID string `json:"organization_id"`
	Name           string `json:"name"`
}

func categoryToDTO(c *domain.Category) categoryDTO {
	return categoryDTO{
		ID:             c.ID.String(),
		OrganizationID: c.OrganizationID.String(),
		CreatedByID:    c.CreatedByID.String(),
		Name:           c.Name,
		CreatedAt:      c.CreatedAt,
	}
}

func (h *CategoriesHandler) List(w http.ResponseWriter, r *http.Request) {
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
	cats, err := h.categories.List(r.Context(), userID, orgID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]categoryDTO, 0, len(cats))
	for i := range cats {
		dtos = append(dtos, categoryToDTO(&cats[i]))
	}
	writeJSON(w, http.StatusOK, categoryListResponse{Categories: dtos})
}

func (h *CategoriesHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req createCategoryRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	orgID, err := parseRequiredUUID(req.OrganizationID, "organization_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	cat, err := h.categories.Create(r.Context(), usecase.CreateCategoryInput{
		UserID:         userID,
		OrganizationID: orgID,
		Name:           req.Name,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, categoryResponse{Category: categoryToDTO(cat)})
}

func (h *CategoriesHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
	if err := h.categories.Delete(r.Context(), userID, id); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
