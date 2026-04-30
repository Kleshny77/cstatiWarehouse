package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

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
	UserID    string    `json:"user_id"`
	Role      string    `json:"role"`
	JoinedAt  time.Time `json:"joined_at"`
	Name      string    `json:"name"`
	LastName  string    `json:"last_name"`
	Email     string    `json:"email"`
	AvatarURL *string   `json:"avatar_url,omitempty"`
}

type organizationMembersResponse struct {
	Members []organizationMemberDTO `json:"members"`
}

type inviteDTO struct {
	ID             string     `json:"id"`
	OrganizationID string     `json:"organization_id"`
	Code           string     `json:"code"`
	CreatedByID    string     `json:"created_by_id"`
	CreatedAt      time.Time  `json:"created_at"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
	MaxUses        *int       `json:"max_uses,omitempty"`
	UsedCount      int        `json:"used_count"`
	RevokedAt      *time.Time `json:"revoked_at,omitempty"`
	IsActive       bool       `json:"is_active"`
}

type invitesResponse struct {
	Invites []inviteDTO `json:"invites"`
}

type inviteResponse struct {
	Invite inviteDTO `json:"invite"`
}

type createInviteRequest struct {
	ExpiresInDays *int `json:"expires_in_days,omitempty"`
	MaxUses       *int `json:"max_uses,omitempty"`
}

type joinByCodeRequest struct {
	Code string `json:"code"`
}

type changeRoleRequest struct {
	Role string `json:"role"`
}

type transferOwnershipRequest struct {
	NewOwnerID string `json:"new_owner_id"`
}

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
	_, role, err := h.orgs.Get(r.Context(), userID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, organizationResponse{Organization: orgToDTO(org, role)})
}

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
		dtos = append(dtos, memberToDTO(m))
	}
	writeJSON(w, http.StatusOK, organizationMembersResponse{Members: dtos})
}

func (h *OrganizationHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	targetID, err := parseIDPath(r, "userId")
	if err != nil {
		writeError(w, r, err)
		return
	}
	if err := h.orgs.RemoveMember(r.Context(), actorID, orgID, targetID); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OrganizationHandler) ChangeRole(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	targetID, err := parseIDPath(r, "userId")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req changeRoleRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	role := domain.OrgRole(strings.ToLower(strings.TrimSpace(req.Role)))
	if !domain.IsValidOrgRole(role) {
		writeError(w, r, domain.NewValidationError("invalid role"))
		return
	}
	if err := h.orgs.ChangeRole(r.Context(), usecase.ChangeRoleInput{
		ActorID: actorID, OrgID: orgID, TargetID: targetID, NewRole: role,
	}); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OrganizationHandler) TransferOwnership(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req transferOwnershipRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	target, err := uuid.Parse(req.NewOwnerID)
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid new_owner_id"))
		return
	}
	if err := h.orgs.TransferOwnership(r.Context(), actorID, orgID, target); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OrganizationHandler) ListInvites(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	invites, err := h.orgs.ListInvites(r.Context(), actorID, orgID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	now := time.Now()
	dtos := make([]inviteDTO, 0, len(invites))
	for _, inv := range invites {
		i := inv
		dtos = append(dtos, inviteToDTO(&i, now))
	}
	writeJSON(w, http.StatusOK, invitesResponse{Invites: dtos})
}

func (h *OrganizationHandler) CreateInvite(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var req createInviteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	in := usecase.CreateInviteInput{ActorID: actorID, OrgID: orgID, MaxUses: req.MaxUses}
	if req.ExpiresInDays != nil {
		if *req.ExpiresInDays <= 0 {
			writeError(w, r, domain.NewValidationError("expires_in_days must be positive"))
			return
		}
		d := time.Duration(*req.ExpiresInDays) * 24 * time.Hour
		in.ExpiresIn = &d
	}
	invite, err := h.orgs.CreateInvite(r.Context(), in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, inviteResponse{Invite: inviteToDTO(invite, time.Now())})
}

func (h *OrganizationHandler) RevokeInvite(w http.ResponseWriter, r *http.Request) {
	actorID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	orgID, err := parseIDPath(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	inviteID, err := parseIDPath(r, "inviteId")
	if err != nil {
		writeError(w, r, err)
		return
	}
	if err := h.orgs.RevokeInvite(r.Context(), actorID, orgID, inviteID); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *OrganizationHandler) JoinByCode(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	var req joinByCodeRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, r, err)
		return
	}
	org, role, err := h.orgs.JoinByCode(r.Context(), userID, req.Code)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, organizationResponse{Organization: orgToDTO(org, role)})
}

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

func memberToDTO(m usecase.MemberWithProfile) organizationMemberDTO {
	return organizationMemberDTO{
		UserID:    m.Member.UserID.String(),
		Role:      string(m.Member.Role),
		JoinedAt:  m.Member.JoinedAt,
		Name:      m.Name,
		LastName:  m.LastName,
		Email:     m.Email,
		AvatarURL: m.AvatarURL,
	}
}

func inviteToDTO(inv *domain.Invite, now time.Time) inviteDTO {
	return inviteDTO{
		ID:             inv.ID.String(),
		OrganizationID: inv.OrganizationID.String(),
		Code:           inv.Code,
		CreatedByID:    inv.CreatedByUserID.String(),
		CreatedAt:      inv.CreatedAt,
		ExpiresAt:      inv.ExpiresAt,
		MaxUses:        inv.MaxUses,
		UsedCount:      inv.UsedCount,
		RevokedAt:      inv.RevokedAt,
		IsActive:       inv.IsUsable(now),
	}
}
