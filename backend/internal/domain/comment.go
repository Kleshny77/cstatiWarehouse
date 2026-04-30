package domain

import (
	"time"

	"github.com/google/uuid"
)

type CommentReactionType string

const (
	ReactionThumbsUp   CommentReactionType = "thumbs_up"
	ReactionThumbsDown CommentReactionType = "thumbs_down"
	ReactionHeart      CommentReactionType = "heart"
	ReactionLaugh      CommentReactionType = "laugh"
	ReactionParty      CommentReactionType = "party"
	ReactionEyes       CommentReactionType = "eyes"
)

func (r CommentReactionType) IsValid() bool {
	switch r {
	case ReactionThumbsUp, ReactionThumbsDown, ReactionHeart, ReactionLaugh, ReactionParty, ReactionEyes:
		return true
	}
	return false
}

type ItemComment struct {
	ID             uuid.UUID
	ItemID         uuid.UUID
	OrganizationID uuid.UUID

	Text             string
	MentionedUserIDs []uuid.UUID
	AttachmentURLs   []string

	AuthorUserID uuid.UUID

	CreatedAt time.Time
	UpdatedAt time.Time
	EditedAt  *time.Time

	DeletedAt       *time.Time
	DeletedByUserID *uuid.UUID

	ParentCommentID *uuid.UUID

	Reactions []CommentReaction
}

func (c *ItemComment) IsDeleted() bool { return c.DeletedAt != nil }
func (c *ItemComment) IsEdited() bool  { return c.EditedAt != nil }

func (c *ItemComment) CanBeEditedBy(userID uuid.UUID) bool {
	return !c.IsDeleted() && c.AuthorUserID == userID
}

func (c *ItemComment) CanBeDeletedBy(userID uuid.UUID, isAdmin bool) bool {
	if c.IsDeleted() {
		return false
	}
	return c.AuthorUserID == userID || isAdmin
}

type CommentReaction struct {
	ID        uuid.UUID
	CommentID uuid.UUID
	UserID    uuid.UUID
	Reaction  CommentReactionType
	CreatedAt time.Time
}

type CommentEditHistoryEntry struct {
	ID             uuid.UUID
	CommentID      uuid.UUID
	PreviousText   string
	EditedByUserID uuid.UUID
	EditedAt       time.Time
}
