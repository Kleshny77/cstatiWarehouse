# Item Comments System — Система комментариев к позициям

## Overview

Система комментариев позволяет участникам организации обсуждать позиции склада, оставлять заметки, задавать вопросы и координировать действия. Это улучшает коммуникацию в команде и создает историю обсуждений для каждой позиции.

## Business Requirements

### Use Cases

1. **Обсуждение позиции**
   - Менеджер спрашивает: "Когда ожидается поставка?"
   - Закупщик отвечает: "Завтра утром, 50 единиц"
   - История сохраняется для всей команды

2. **Заметки о качестве**
   - Кладовщик: "Партия #123 имеет дефекты упаковки"
   - Менеджер: "Отметил, будем возвращать поставщику"

3. **Координация действий**
   - Водитель: "Беру 20 единиц для доставки на адрес X"
   - Менеджер: "Ок, зарезервировал"

4. **Упоминания (@mentions)**
   - "@ivan проверь срок годности этой партии"
   - Иван получает push-уведомление

5. **Прикрепление файлов**
   - Фото дефекта
   - Документы (накладные, сертификаты)
   - Скриншоты переписки с поставщиком

### Key Features

- ✅ Текстовые комментарии с markdown поддержкой
- ✅ Упоминания пользователей (@username)
- ✅ Прикрепление изображений и файлов
- ✅ Редактирование и удаление своих комментариев
- ✅ Реакции (👍 👎 ❤️ 😂 🎉)
- ✅ Уведомления при упоминании
- ✅ Real-time обновления через WebSocket
- ✅ История изменений комментария
- ✅ Поиск по комментариям

## Database Schema

### Migration: `00023_add_item_comments.sql`

```sql
-- Create item_comments table
CREATE TABLE item_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Comment content
    text TEXT NOT NULL CHECK (length(text) > 0 AND length(text) <= 5000),
    
    -- Author
    author_user_id UUID NOT NULL REFERENCES users(id),
    
    -- Mentions
    mentioned_user_ids UUID[] DEFAULT '{}',
    
    -- Attachments (URLs to uploaded files)
    attachment_urls TEXT[] DEFAULT '{}',
    
    -- Lifecycle
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ, -- NULL if never edited
    deleted_at TIMESTAMPTZ, -- Soft delete
    deleted_by_user_id UUID REFERENCES users(id),
    
    -- Parent comment for threading (optional feature)
    parent_comment_id UUID REFERENCES item_comments(id) ON DELETE CASCADE,
    
    CONSTRAINT valid_text_length CHECK (length(trim(text)) > 0)
);

-- Create comment_reactions table
CREATE TABLE comment_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES item_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    reaction VARCHAR(10) NOT NULL, -- emoji: 'thumbs_up', 'heart', 'laugh', etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- One reaction per user per comment
    UNIQUE(comment_id, user_id, reaction)
);

-- Create comment_edit_history table (optional, for audit trail)
CREATE TABLE comment_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES item_comments(id) ON DELETE CASCADE,
    previous_text TEXT NOT NULL,
    edited_by_user_id UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX idx_item_comments_item_id ON item_comments(item_id);
CREATE INDEX idx_item_comments_organization_id ON item_comments(organization_id);
CREATE INDEX idx_item_comments_author ON item_comments(author_user_id);
CREATE INDEX idx_item_comments_created_at ON item_comments(created_at DESC);

-- Partial index for active (non-deleted) comments
CREATE INDEX idx_item_comments_active ON item_comments(item_id, organization_id) 
WHERE deleted_at IS NULL;

-- GIN index for mentioned users array
CREATE INDEX idx_item_comments_mentioned_users ON item_comments USING GIN(mentioned_user_ids);

-- Full-text search index
CREATE INDEX idx_item_comments_text_search ON item_comments USING GIN(to_tsvector('russian', text))
WHERE deleted_at IS NULL;

-- Indexes for reactions
CREATE INDEX idx_comment_reactions_comment_id ON comment_reactions(comment_id);
CREATE INDEX idx_comment_reactions_user_id ON comment_reactions(user_id);

-- Trigger to update updated_at
CREATE TRIGGER update_item_comments_updated_at
    BEFORE UPDATE ON item_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to save edit history
CREATE OR REPLACE FUNCTION save_comment_edit_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Only save if text changed and not a delete operation
    IF OLD.text IS DISTINCT FROM NEW.text AND NEW.deleted_at IS NULL THEN
        INSERT INTO comment_edit_history (comment_id, previous_text, edited_by_user_id, edited_at)
        VALUES (OLD.id, OLD.text, NEW.author_user_id, NOW());
        
        NEW.edited_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER save_comment_edit_history_trigger
    BEFORE UPDATE ON item_comments
    FOR EACH ROW
    EXECUTE FUNCTION save_comment_edit_history();
```

### Mention Extraction Function

```sql
-- Function to extract @mentions from text
CREATE OR REPLACE FUNCTION extract_mentions(text TEXT)
RETURNS UUID[] AS $$
DECLARE
    mention_pattern TEXT := '@([a-zA-Z0-9_]+)';
    usernames TEXT[];
    user_ids UUID[];
BEGIN
    -- Extract all @username patterns
    SELECT array_agg(DISTINCT (regexp_matches(text, mention_pattern, 'g'))[1])
    INTO usernames;
    
    IF usernames IS NULL THEN
        RETURN '{}';
    END IF;
    
    -- Convert usernames to user IDs
    SELECT array_agg(id)
    INTO user_ids
    FROM users
    WHERE username = ANY(usernames);
    
    RETURN COALESCE(user_ids, '{}');
END;
$$ LANGUAGE plpgsql;
```

## Backend Implementation

### Domain Model

**`backend/internal/domain/comment.go`**:

```go
package domain

import (
    "time"
    "github.com/google/uuid"
)

type ItemComment struct {
    ID             uuid.UUID
    ItemID         uuid.UUID
    OrganizationID uuid.UUID
    
    // Content
    Text               string
    MentionedUserIDs   []uuid.UUID
    AttachmentURLs     []string
    
    // Author
    AuthorUserID uuid.UUID
    
    // Lifecycle
    CreatedAt        time.Time
    UpdatedAt        time.Time
    EditedAt         *time.Time
    DeletedAt        *time.Time
    DeletedByUserID  *uuid.UUID
    
    // Threading (optional)
    ParentCommentID *uuid.UUID
    
    // Reactions (loaded separately)
    Reactions []CommentReaction `json:"reactions,omitempty"`
}

func (c *ItemComment) IsDeleted() bool {
    return c.DeletedAt != nil
}

func (c *ItemComment) IsEdited() bool {
    return c.EditedAt != nil
}

func (c *ItemComment) CanBeEditedBy(userID uuid.UUID) bool {
    return c.AuthorUserID == userID && !c.IsDeleted()
}

func (c *ItemComment) CanBeDeletedBy(userID uuid.UUID, isAdmin bool) bool {
    if c.IsDeleted() {
        return false
    }
    // Can delete own comment or admin can delete any
    return c.AuthorUserID == userID || isAdmin
}

type CommentReaction struct {
    ID        uuid.UUID
    CommentID uuid.UUID
    UserID    uuid.UUID
    Reaction  string // emoji name: thumbs_up, heart, laugh, etc.
    CreatedAt time.Time
}

type CommentEditHistory struct {
    ID            uuid.UUID
    CommentID     uuid.UUID
    PreviousText  string
    EditedByUserID uuid.UUID
    EditedAt      time.Time
}
```

### Use Case

**`backend/internal/usecase/comments.go`**:

```go
package usecase

import (
    "context"
    "regexp"
    "strings"
    "time"
    
    "github.com/google/uuid"
    "cstatiWarehouse/internal/domain"
)

type CommentsUseCase struct {
    repo          CommentRepository
    itemRepo      ItemRepository
    userRepo      UserRepository
    orgRepo       OrganizationRepository
    broadcaster   WebSocketBroadcaster
    notifications NotificationService
}

type CreateCommentInput struct {
    ItemID         uuid.UUID
    OrganizationID uuid.UUID
    Text           string
    AttachmentURLs []string
    ParentCommentID *uuid.UUID
}

func (uc *CommentsUseCase) CreateComment(ctx context.Context, in CreateCommentInput) (*domain.ItemComment, error) {
    userID := GetUserIDFromContext(ctx)
    
    // Validate organization membership
    member, err := uc.orgRepo.GetMember(ctx, in.OrganizationID, userID)
    if err != nil {
        return nil, domain.ErrUnauthorized
    }
    
    // Validate item exists and belongs to organization
    item, err := uc.itemRepo.GetByID(ctx, in.ItemID)
    if err != nil {
        return nil, err
    }
    if item.OrganizationID != in.OrganizationID {
        return nil, domain.ErrNotFound
    }
    
    // Validate text length
    text := strings.TrimSpace(in.Text)
    if len(text) == 0 || len(text) > 5000 {
        return nil, domain.ErrInvalidInput
    }
    
    // Extract mentions
    mentionedUserIDs := uc.extractMentions(ctx, text, in.OrganizationID)
    
    // Create comment
    comment := &domain.ItemComment{
        ID:               uuid.New(),
        ItemID:           in.ItemID,
        OrganizationID:   in.OrganizationID,
        Text:             text,
        MentionedUserIDs: mentionedUserIDs,
        AttachmentURLs:   in.AttachmentURLs,
        AuthorUserID:     userID,
        ParentCommentID:  in.ParentCommentID,
        CreatedAt:        time.Now(),
        UpdatedAt:        time.Now(),
    }
    
    if err := uc.repo.Create(ctx, comment); err != nil {
        return nil, err
    }
    
    // Load author info for broadcast
    author, _ := uc.userRepo.GetByID(ctx, userID)
    
    // Broadcast to organization
    uc.broadcaster.BroadcastToOrganization(in.OrganizationID, WebSocketMessage{
        Type: "comment_created",
        Data: map[string]interface{}{
            "comment": comment,
            "author":  author,
        },
    })
    
    // Send notifications to mentioned users
    for _, mentionedUserID := range mentionedUserIDs {
        if mentionedUserID != userID { // Don't notify self
            uc.notifications.SendCommentMention(ctx, mentionedUserID, comment, author)
        }
    }
    
    return comment, nil
}

type UpdateCommentInput struct {
    CommentID uuid.UUID
    Text      string
}

func (uc *CommentsUseCase) UpdateComment(ctx context.Context, in UpdateCommentInput) (*domain.ItemComment, error) {
    userID := GetUserIDFromContext(ctx)
    
    comment, err := uc.repo.GetByID(ctx, in.CommentID)
    if err != nil {
        return nil, err
    }
    
    // Check permissions
    if !comment.CanBeEditedBy(userID) {
        return nil, domain.ErrForbidden
    }
    
    // Validate text
    text := strings.TrimSpace(in.Text)
    if len(text) == 0 || len(text) > 5000 {
        return nil, domain.ErrInvalidInput
    }
    
    // Extract new mentions
    mentionedUserIDs := uc.extractMentions(ctx, text, comment.OrganizationID)
    
    // Update comment
    comment.Text = text
    comment.MentionedUserIDs = mentionedUserIDs
    
    if err := uc.repo.Update(ctx, comment); err != nil {
        return nil, err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(comment.OrganizationID, WebSocketMessage{
        Type: "comment_updated",
        Data: comment,
    })
    
    // Notify newly mentioned users
    for _, mentionedUserID := range mentionedUserIDs {
        if mentionedUserID != userID {
            author, _ := uc.userRepo.GetByID(ctx, userID)
            uc.notifications.SendCommentMention(ctx, mentionedUserID, comment, author)
        }
    }
    
    return comment, nil
}

func (uc *CommentsUseCase) DeleteComment(ctx context.Context, commentID uuid.UUID) error {
    userID := GetUserIDFromContext(ctx)
    
    comment, err := uc.repo.GetByID(ctx, commentID)
    if err != nil {
        return err
    }
    
    // Check permissions
    member, err := uc.orgRepo.GetMember(ctx, comment.OrganizationID, userID)
    if err != nil {
        return domain.ErrUnauthorized
    }
    
    isAdmin := member.Role == domain.RoleOwner || member.Role == domain.RoleAdmin
    if !comment.CanBeDeletedBy(userID, isAdmin) {
        return domain.ErrForbidden
    }
    
    // Soft delete
    now := time.Now()
    comment.DeletedAt = &now
    comment.DeletedByUserID = &userID
    
    if err := uc.repo.Update(ctx, comment); err != nil {
        return err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(comment.OrganizationID, WebSocketMessage{
        Type: "comment_deleted",
        Data: map[string]interface{}{
            "comment_id": commentID,
        },
    })
    
    return nil
}

func (uc *CommentsUseCase) ListComments(ctx context.Context, itemID uuid.UUID) ([]domain.ItemComment, error) {
    userID := GetUserIDFromContext(ctx)
    
    // Get item to validate access
    item, err := uc.itemRepo.GetByID(ctx, itemID)
    if err != nil {
        return nil, err
    }
    
    // Validate membership
    _, err = uc.orgRepo.GetMember(ctx, item.OrganizationID, userID)
    if err != nil {
        return nil, domain.ErrUnauthorized
    }
    
    comments, err := uc.repo.ListByItem(ctx, itemID)
    if err != nil {
        return nil, err
    }
    
    // Load reactions for each comment
    for i := range comments {
        reactions, _ := uc.repo.GetReactions(ctx, comments[i].ID)
        comments[i].Reactions = reactions
    }
    
    return comments, nil
}

type AddReactionInput struct {
    CommentID uuid.UUID
    Reaction  string
}

func (uc *CommentsUseCase) AddReaction(ctx context.Context, in AddReactionInput) error {
    userID := GetUserIDFromContext(ctx)
    
    comment, err := uc.repo.GetByID(ctx, in.CommentID)
    if err != nil {
        return err
    }
    
    // Validate membership
    _, err = uc.orgRepo.GetMember(ctx, comment.OrganizationID, userID)
    if err != nil {
        return domain.ErrUnauthorized
    }
    
    // Validate reaction
    if !isValidReaction(in.Reaction) {
        return domain.ErrInvalidInput
    }
    
    reaction := &domain.CommentReaction{
        ID:        uuid.New(),
        CommentID: in.CommentID,
        UserID:    userID,
        Reaction:  in.Reaction,
        CreatedAt: time.Now(),
    }
    
    if err := uc.repo.AddReaction(ctx, reaction); err != nil {
        return err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(comment.OrganizationID, WebSocketMessage{
        Type: "reaction_added",
        Data: reaction,
    })
    
    return nil
}

func (uc *CommentsUseCase) RemoveReaction(ctx context.Context, commentID uuid.UUID, reaction string) error {
    userID := GetUserIDFromContext(ctx)
    
    comment, err := uc.repo.GetByID(ctx, commentID)
    if err != nil {
        return err
    }
    
    // Validate membership
    _, err = uc.orgRepo.GetMember(ctx, comment.OrganizationID, userID)
    if err != nil {
        return domain.ErrUnauthorized
    }
    
    if err := uc.repo.RemoveReaction(ctx, commentID, userID, reaction); err != nil {
        return err
    }
    
    // Broadcast
    uc.broadcaster.BroadcastToOrganization(comment.OrganizationID, WebSocketMessage{
        Type: "reaction_removed",
        Data: map[string]interface{}{
            "comment_id": commentID,
            "user_id":    userID,
            "reaction":   reaction,
        },
    })
    
    return nil
}

// Helper: Extract @mentions from text
func (uc *CommentsUseCase) extractMentions(ctx context.Context, text string, orgID uuid.UUID) []uuid.UUID {
    // Regex to match @username
    re := regexp.MustCompile(`@([a-zA-Z0-9_]+)`)
    matches := re.FindAllStringSubmatch(text, -1)
    
    if len(matches) == 0 {
        return nil
    }
    
    // Extract unique usernames
    usernameSet := make(map[string]bool)
    for _, match := range matches {
        if len(match) > 1 {
            usernameSet[match[1]] = true
        }
    }
    
    usernames := make([]string, 0, len(usernameSet))
    for username := range usernameSet {
        usernames = append(usernames, username)
    }
    
    // Get user IDs from usernames (only org members)
    members, err := uc.orgRepo.ListMembers(ctx, orgID)
    if err != nil {
        return nil
    }
    
    var userIDs []uuid.UUID
    for _, member := range members {
        user, err := uc.userRepo.GetByID(ctx, member.UserID)
        if err != nil {
            continue
        }
        for _, username := range usernames {
            if user.Username == username {
                userIDs = append(userIDs, user.ID)
                break
            }
        }
    }
    
    return userIDs
}

func isValidReaction(reaction string) bool {
    validReactions := []string{"thumbs_up", "thumbs_down", "heart", "laugh", "party", "eyes"}
    for _, valid := range validReactions {
        if reaction == valid {
            return true
        }
    }
    return false
}
```

### Repository Interface

**`backend/internal/usecase/ports.go`** (add):

```go
type CommentRepository interface {
    Create(ctx context.Context, comment *domain.ItemComment) error
    Update(ctx context.Context, comment *domain.ItemComment) error
    GetByID(ctx context.Context, id uuid.UUID) (*domain.ItemComment, error)
    ListByItem(ctx context.Context, itemID uuid.UUID) ([]domain.ItemComment, error)
    Delete(ctx context.Context, id uuid.UUID) error
    
    // Reactions
    AddReaction(ctx context.Context, reaction *domain.CommentReaction) error
    RemoveReaction(ctx context.Context, commentID, userID uuid.UUID, reaction string) error
    GetReactions(ctx context.Context, commentID uuid.UUID) ([]domain.CommentReaction, error)
    
    // Search
    Search(ctx context.Context, orgID uuid.UUID, query string) ([]domain.ItemComment, error)
}
```

### HTTP Handler

**`backend/internal/adapter/httpapi/comments_handler.go`**:

```go
package httpapi

import (
    "encoding/json"
    "net/http"
    
    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"
    "cstatiWarehouse/internal/usecase"
)

type CommentsHandler struct {
    uc *usecase.CommentsUseCase
}

func NewCommentsHandler(uc *usecase.CommentsUseCase) *CommentsHandler {
    return &CommentsHandler{uc: uc}
}

type createCommentRequest struct {
    Text            string   `json:"text"`
    AttachmentURLs  []string `json:"attachment_urls"`
    ParentCommentID *string  `json:"parent_comment_id"`
}

func (h *CommentsHandler) Create(w http.ResponseWriter, r *http.Request) {
    orgID, err := uuid.Parse(chi.URLParam(r, "orgID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid organization ID")
        return
    }
    
    itemID, err := uuid.Parse(chi.URLParam(r, "itemID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid item ID")
        return
    }
    
    var req createCommentRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    var parentCommentID *uuid.UUID
    if req.ParentCommentID != nil {
        id, err := uuid.Parse(*req.ParentCommentID)
        if err != nil {
            respondError(w, http.StatusBadRequest, "invalid parent_comment_id")
            return
        }
        parentCommentID = &id
    }
    
    comment, err := h.uc.CreateComment(r.Context(), usecase.CreateCommentInput{
        ItemID:          itemID,
        OrganizationID:  orgID,
        Text:            req.Text,
        AttachmentURLs:  req.AttachmentURLs,
        ParentCommentID: parentCommentID,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    respondJSON(w, http.StatusCreated, comment)
}

func (h *CommentsHandler) List(w http.ResponseWriter, r *http.Request) {
    itemID, err := uuid.Parse(chi.URLParam(r, "itemID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid item ID")
        return
    }
    
    comments, err := h.uc.ListComments(r.Context(), itemID)
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    respondJSON(w, http.StatusOK, comments)
}

type updateCommentRequest struct {
    Text string `json:"text"`
}

func (h *CommentsHandler) Update(w http.ResponseWriter, r *http.Request) {
    commentID, err := uuid.Parse(chi.URLParam(r, "commentID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid comment ID")
        return
    }
    
    var req updateCommentRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    comment, err := h.uc.UpdateComment(r.Context(), usecase.UpdateCommentInput{
        CommentID: commentID,
        Text:      req.Text,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    respondJSON(w, http.StatusOK, comment)
}

func (h *CommentsHandler) Delete(w http.ResponseWriter, r *http.Request) {
    commentID, err := uuid.Parse(chi.URLParam(r, "commentID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid comment ID")
        return
    }
    
    err = h.uc.DeleteComment(r.Context(), commentID)
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}

type addReactionRequest struct {
    Reaction string `json:"reaction"`
}

func (h *CommentsHandler) AddReaction(w http.ResponseWriter, r *http.Request) {
    commentID, err := uuid.Parse(chi.URLParam(r, "commentID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid comment ID")
        return
    }
    
    var req addReactionRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    err = h.uc.AddReaction(r.Context(), usecase.AddReactionInput{
        CommentID: commentID,
        Reaction:  req.Reaction,
    })
    
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}

func (h *CommentsHandler) RemoveReaction(w http.ResponseWriter, r *http.Request) {
    commentID, err := uuid.Parse(chi.URLParam(r, "commentID"))
    if err != nil {
        respondError(w, http.StatusBadRequest, "invalid comment ID")
        return
    }
    
    reaction := r.URL.Query().Get("reaction")
    if reaction == "" {
        respondError(w, http.StatusBadRequest, "reaction parameter required")
        return
    }
    
    err = h.uc.RemoveReaction(r.Context(), commentID, reaction)
    if err != nil {
        respondDomainError(w, err)
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}
```

### Router Integration

**`backend/internal/adapter/httpapi/router.go`** (add):

```go
// Comments
r.Route("/organizations/{orgID}/items/{itemID}/comments", func(r chi.Router) {
    r.Use(authMiddleware)
    r.Post("/", commentsHandler.Create)
    r.Get("/", commentsHandler.List)
})

r.Route("/comments/{commentID}", func(r chi.Router) {
    r.Use(authMiddleware)
    r.Put("/", commentsHandler.Update)
    r.Delete("/", commentsHandler.Delete)
    r.Post("/reactions", commentsHandler.AddReaction)
    r.Delete("/reactions", commentsHandler.RemoveReaction)
})
```

## iOS Implementation

### Domain Model

**`ios/cstatiWarehouse/Entity/ItemComment.swift`**:

```swift
//
//  ItemComment.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import SwiftUI

struct ItemComment: Identifiable, Codable, Hashable {
    let id: UUID
    let itemId: UUID
    let organizationId: UUID
    
    let text: String
    let mentionedUserIds: [UUID]
    let attachmentUrls: [String]
    
    let authorUserId: UUID
    
    let createdAt: Date
    let updatedAt: Date
    let editedAt: Date?
    let deletedAt: Date?
    let deletedByUserId: UUID?
    
    let parentCommentId: UUID?
    
    var reactions: [CommentReaction]
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    var isEdited: Bool {
        editedAt != nil
    }
    
    var displayText: String {
        isDeleted ? "[Комментарий удален]" : text
    }
    
    func canBeEditedBy(_ userId: UUID) -> Bool {
        authorUserId == userId && !isDeleted
    }
    
    func canBeDeletedBy(_ userId: UUID, isAdmin: Bool) -> Bool {
        !isDeleted && (authorUserId == userId || isAdmin)
    }
    
    func reactionCount(for reaction: ReactionType) -> Int {
        reactions.filter { $0.reaction == reaction.rawValue }.count
    }
    
    func hasReaction(_ reaction: ReactionType, from userId: UUID) -> Bool {
        reactions.contains { $0.reaction == reaction.rawValue && $0.userId == userId }
    }
}

struct CommentReaction: Identifiable, Codable, Hashable {
    let id: UUID
    let commentId: UUID
    let userId: UUID
    let reaction: String
    let createdAt: Date
}

enum ReactionType: String, CaseIterable {
    case thumbsUp = "thumbs_up"
    case thumbsDown = "thumbs_down"
    case heart = "heart"
    case laugh = "laugh"
    case party = "party"
    case eyes = "eyes"
    
    var emoji: String {
        switch self {