package httpapi

import (
	"net/http"
	"time"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type OrganizationHandler struct {
	orgs *usecase.OrganizationsUseCase
}

func NewOrganizationHandler(orgs *usecase.OrganizationsUseCase) *OrganizationHandler {
	return &OrganizationHandler{orgs: orgs}
}

type organizationDTO struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	OwnerID    string    `json:"owner_id"`
	IsPersonal bool      `json:"is_personal"`
	MyRole     string    `json:"my_role"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type organizationListResponse struct {
	Organizations []organizationDTO `json:"organizations"`
}

type organizationResponse struct {
	Organization organizationDTO `json:"organization"`
}

type createOrganizationRequest struct {
	Name string `json:"name"`
}

type updateOrganizationRequest struct {
	Name *string `json:"name,omitempty"`
}

type organizationMemberDTO struct {
	UserID   string    `json:"user_id"`
	Role     string    `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
}

type organizationMembersResponse struct {
	Members []organizationMemberDTO `json:"members"`
}

// List — GET /organizations: организации, в которых состоит текущий пользователь.
func (h *OrganizationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgs, err := h.orgs.ListMine(r.Context(), userID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]organizationDTO, 0, len(orgs))
	for _, o := range orgs {
		dtos = append(dtos, orgWithRoleToDTO(o))
	}
	writeJSON(w, http.StatusOK, organizationListResponse{Organizations: dtos})
}

// Create — POST /organizations: создать новую (не персональную) организацию.
func (h *OrganizationHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req createOrganizationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	org, err := h.orgs.Create(r.Context(), usecase.CreateOrganizationInput{
		OwnerID: userID,
		Name:    req.Name,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, organizationResponse{
		Organization: orgToDTO(org, domain.OrgRoleOwner),
	})
}

// Get — GET /organizations/{id}.
func (h *OrganizationHandler) Get(w http.ResponseWriter, r *http.Request) {
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
	org, role, err := h.orgs.Get(r.Context(), userID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, organizationResponse{Organization: orgToDTO(org, role)})
}

// Update — PATCH /organizations/{id}.
func (h *OrganizationHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var req updateOrganizationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	org, err := h.orgs.Update(r.Context(), usecase.UpdateOrganizationInput{
		UserID: userID,
		OrgID:  id,
		Name:   req.Name,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	// После Update роль уже известна — owner/admin, но удобнее перепрочитать её.
	_, role, err := h.orgs.Get(r.Context(), userID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, organizationResponse{Organization: orgToDTO(org, role)})
}

// Delete — DELETE /organizations/{id}.
func (h *OrganizationHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
	if err := h.orgs.Delete(r.Context(), userID, id); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Members — GET /organizations/{id}/members.
func (h *OrganizationHandler) Members(w http.ResponseWriter, r *http.Request) {
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
	members, err := h.orgs.ListMembers(r.Context(), userID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	dtos := make([]organizationMemberDTO, 0, len(members))
	for _, m := range members {
		dtos = append(dtos, organizationMemberDTO{
			UserID:   m.UserID.String(),
			Role:     string(m.Role),
			JoinedAt: m.JoinedAt,
		})
	}
	writeJSON(w, http.StatusOK, organizationMembersResponse{Members: dtos})
}

// Leave — POST /organizations/{id}/leave.
func (h *OrganizationHandler) Leave(w http.ResponseWriter, r *http.Request) {
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
	if err := h.orgs.Leave(r.Context(), userID, id); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func orgToDTO(o *domain.Organization, role domain.OrgRole) organizationDTO {
	return organizationDTO{
		ID:         o.ID.String(),
		Name:       o.Name,
		OwnerID:    o.OwnerID.String(),
		IsPersonal: o.IsPersonal,
		MyRole:     string(role),
		CreatedAt:  o.CreatedAt,
		UpdatedAt:  o.UpdatedAt,
	}
}

func orgWithRoleToDTO(o usecase.OrganizationWithRole) organizationDTO {
	return orgToDTO(&o.Organization, o.Role)
}
