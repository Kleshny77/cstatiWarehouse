package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
	"github.com/Kleshny77/cstatiWarehouse/backend/internal/usecase"
)

type CommentsHandler struct {
	uc *usecase.CommentsUseCase
}

func NewCommentsHandler(uc *usecase.CommentsUseCase) *CommentsHandler {
	return &CommentsHandler{uc: uc}
}


type commentReactionDTO struct {
	ID        string `json:"id"`
	CommentID string `json:"comment_id"`
	UserID    string `json:"user_id"`
	Reaction  string `json:"reaction"`
	CreatedAt string `json:"created_at"`
}

type itemCommentDTO struct {
	ID               string               `json:"id"`
	ItemID           string               `json:"item_id"`
	OrganizationID   string               `json:"organization_id"`
	Text             string               `json:"text"`
	MentionedUserIDs []string             `json:"mentioned_user_ids"`
	AttachmentURLs   []string             `json:"attachment_urls"`
	AuthorUserID     string               `json:"author_user_id"`
	CreatedAt        string               `json:"created_at"`
	UpdatedAt        string               `json:"updated_at"`
	EditedAt         *string              `json:"edited_at,omitempty"`
	DeletedAt        *string              `json:"deleted_at,omitempty"`
	DeletedByUserID  *string              `json:"deleted_by_user_id,omitempty"`
	ParentCommentID  *string              `json:"parent_comment_id,omitempty"`
	Reactions        []commentReactionDTO `json:"reactions"`
}

func toCommentDTO(c domain.ItemComment) itemCommentDTO {
	mentions := make([]string, 0, len(c.MentionedUserIDs))
	for _, id := range c.MentionedUserIDs {
		mentions = append(mentions, id.String())
	}
	attaches := make([]string, 0, len(c.AttachmentURLs))
	attaches = append(attaches, c.AttachmentURLs...)

	reacts := make([]commentReactionDTO, 0, len(c.Reactions))
	for _, r := range c.Reactions {
		reacts = append(reacts, commentReactionDTO{
			ID:        r.ID.String(),
			CommentID: r.CommentID.String(),
			UserID:    r.UserID.String(),
			Reaction:  string(r.Reaction),
			CreatedAt: r.CreatedAt.UTC().Format(time.RFC3339),
		})
	}

	dto := itemCommentDTO{
		ID:               c.ID.String(),
		ItemID:           c.ItemID.String(),
		OrganizationID:   c.OrganizationID.String(),
		Text:             c.Text,
		MentionedUserIDs: mentions,
		AttachmentURLs:   attaches,
		AuthorUserID:     c.AuthorUserID.String(),
		CreatedAt:        c.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:        c.UpdatedAt.UTC().Format(time.RFC3339),
		Reactions:        reacts,
	}
	if c.EditedAt != nil {
		s := c.EditedAt.UTC().Format(time.RFC3339)
		dto.EditedAt = &s
	}
	if c.DeletedAt != nil {
		s := c.DeletedAt.UTC().Format(time.RFC3339)
		dto.DeletedAt = &s
	}
	if c.DeletedByUserID != nil {
		s := c.DeletedByUserID.String()
		dto.DeletedByUserID = &s
	}
	if c.ParentCommentID != nil {
		s := c.ParentCommentID.String()
		dto.ParentCommentID = &s
	}
	return dto
}


type createCommentBody struct {
	Text             string   `json:"text"`
	MentionedUserIDs []string `json:"mentioned_user_ids"`
	AttachmentURLs   []string `json:"attachment_urls"`
	ParentCommentID  *string  `json:"parent_comment_id"`
}

func (h *CommentsHandler) Create(w http.ResponseWriter, r *http.Request) {
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
	var body createCommentBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	mentions, err := parseUUIDList(body.MentionedUserIDs, "mentioned_user_ids")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var parentID *uuid.UUID
	if body.ParentCommentID != nil && *body.ParentCommentID != "" {
		pid, err := uuid.Parse(*body.ParentCommentID)
		if err != nil {
			writeError(w, r, domain.NewValidationError("invalid parent_comment_id"))
			return
		}
		parentID = &pid
	}

	c, err := h.uc.Create(r.Context(), usecase.CreateCommentInput{
		ActorID:          userID,
		ItemID:           itemID,
		Text:             body.Text,
		MentionedUserIDs: mentions,
		AttachmentURLs:   body.AttachmentURLs,
		ParentCommentID:  parentID,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toCommentDTO(*c))
}

func (h *CommentsHandler) List(w http.ResponseWriter, r *http.Request) {
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
	comments, err := h.uc.List(r.Context(), userID, itemID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out := make([]itemCommentDTO, len(comments))
	for i, c := range comments {
		out[i] = toCommentDTO(c)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type updateCommentBody struct {
	Text             string   `json:"text"`
	MentionedUserIDs []string `json:"mentioned_user_ids"`
}

func (h *CommentsHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	commentID, err := uuid.Parse(r.PathValue("commentID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid comment_id"))
		return
	}
	var body updateCommentBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	mentions, err := parseUUIDList(body.MentionedUserIDs, "mentioned_user_ids")
	if err != nil {
		writeError(w, r, err)
		return
	}
	c, err := h.uc.Update(r.Context(), usecase.UpdateCommentInput{
		ActorID:          userID,
		CommentID:        commentID,
		Text:             body.Text,
		MentionedUserIDs: mentions,
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toCommentDTO(*c))
}

func (h *CommentsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	commentID, err := uuid.Parse(r.PathValue("commentID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid comment_id"))
		return
	}
	if err := h.uc.Delete(r.Context(), userID, commentID); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type reactionBody struct {
	Reaction string `json:"reaction"`
}

func (h *CommentsHandler) AddReaction(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	commentID, err := uuid.Parse(r.PathValue("commentID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid comment_id"))
		return
	}
	var body reactionBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, r, domain.NewValidationError("invalid json"))
		return
	}
	if err := h.uc.AddReaction(r.Context(), usecase.AddReactionInput{
		ActorID:   userID,
		CommentID: commentID,
		Reaction:  domain.CommentReactionType(body.Reaction),
	}); err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *CommentsHandler) RemoveReaction(w http.ResponseWriter, r *http.Request) {
	userID, ok := currentUserID(r)
	if !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	commentID, err := uuid.Parse(r.PathValue("commentID"))
	if err != nil {
		writeError(w, r, domain.NewValidationError("invalid comment_id"))
		return
	}
	reactionStr := r.URL.Query().Get("reaction")
	if reactionStr == "" {
		writeError(w, r, domain.NewValidationError("reaction query param required"))
		return
	}
	if err := h.uc.RemoveReaction(
		r.Context(),
		userID,
		commentID,
		domain.CommentReactionType(reactionStr),
	); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func parseUUIDList(values []string, fieldName string) ([]uuid.UUID, error) {
	if len(values) == 0 {
		return nil, nil
	}
	out := make([]uuid.UUID, 0, len(values))
	for _, s := range values {
		if s == "" {
			continue
		}
		id, err := uuid.Parse(s)
		if err != nil {
			return nil, domain.NewValidationError("invalid " + fieldName)
		}
		out = append(out, id)
	}
	return out, nil
}
