package usecase

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type CommentsUseCase struct {
	repo        CommentRepository
	itemRepo    ItemRepository
	memberRepo  OrganizationMemberRepository
	clock       Clock
	broadcaster CommentBroadcaster
}

func NewCommentsUseCase(
	repo CommentRepository,
	itemRepo ItemRepository,
	memberRepo OrganizationMemberRepository,
	clk Clock,
) *CommentsUseCase {
	return &CommentsUseCase{
		repo:       repo,
		itemRepo:   itemRepo,
		memberRepo: memberRepo,
		clock:      clk,
	}
}

func (uc *CommentsUseCase) WithBroadcaster(b CommentBroadcaster) *CommentsUseCase {
	uc.broadcaster = b
	return uc
}

const (
	commentMaxLen  = 5000
	commentMinLen  = 1
	maxAttachments = 10
)

type CreateCommentInput struct {
	ActorID          uuid.UUID
	ItemID           uuid.UUID
	Text             string
	MentionedUserIDs []uuid.UUID
	AttachmentURLs   []string
	ParentCommentID  *uuid.UUID
}

func (uc *CommentsUseCase) Create(ctx context.Context, in CreateCommentInput) (*domain.ItemComment, error) {
	text := strings.TrimSpace(in.Text)
	if len(text) < commentMinLen {
		return nil, domain.NewValidationError("text is empty")
	}
	if len(text) > commentMaxLen {
		return nil, domain.NewValidationError("text is too long")
	}
	if len(in.AttachmentURLs) > maxAttachments {
		return nil, domain.NewValidationError("too many attachments")
	}

	item, err := uc.itemRepo.FindByID(ctx, in.ItemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, domain.ErrNotFound
	}

	if _, err := uc.memberRepo.FindRole(ctx, item.OrganizationID, in.ActorID); err != nil {
		return nil, domain.ErrForbidden
	}

	if in.ParentCommentID != nil {
		parent, err := uc.repo.FindByID(ctx, *in.ParentCommentID)
		if err != nil {
			return nil, err
		}
		if parent == nil || parent.IsDeleted() || parent.ItemID != item.ID {
			return nil, domain.NewValidationError("invalid parent_comment_id")
		}
	}

	mentioned, err := uc.resolveMentions(ctx, item.OrganizationID, in.MentionedUserIDs, text)
	if err != nil {
		return nil, err
	}

	now := uc.clock.Now().UTC()
	c := &domain.ItemComment{
		ID:               uuid.New(),
		ItemID:           item.ID,
		OrganizationID:   item.OrganizationID,
		Text:             text,
		MentionedUserIDs: mentioned,
		AttachmentURLs:   in.AttachmentURLs,
		AuthorUserID:     in.ActorID,
		ParentCommentID:  in.ParentCommentID,
		CreatedAt:        now,
		UpdatedAt:        now,
	}
	if err := uc.repo.Create(ctx, c); err != nil {
		return nil, err
	}

	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastCommentCreated(c.OrganizationID, c)
	}

	return c, nil
}

type UpdateCommentInput struct {
	ActorID          uuid.UUID
	CommentID        uuid.UUID
	Text             string
	MentionedUserIDs []uuid.UUID
}

func (uc *CommentsUseCase) Update(ctx context.Context, in UpdateCommentInput) (*domain.ItemComment, error) {
	text := strings.TrimSpace(in.Text)
	if len(text) < commentMinLen {
		return nil, domain.NewValidationError("text is empty")
	}
	if len(text) > commentMaxLen {
		return nil, domain.NewValidationError("text is too long")
	}

	c, err := uc.repo.FindByID(ctx, in.CommentID)
	if err != nil {
		return nil, err
	}
	if c == nil || c.IsDeleted() {
		return nil, domain.ErrNotFound
	}
	if !c.CanBeEditedBy(in.ActorID) {
		return nil, domain.ErrForbidden
	}

	mentioned, err := uc.resolveMentions(ctx, c.OrganizationID, in.MentionedUserIDs, text)
	if err != nil {
		return nil, err
	}

	now := uc.clock.Now().UTC()
	updated, err := uc.repo.UpdateText(ctx, c.ID, text, mentioned, in.ActorID, now)
	if err != nil {
		return nil, err
	}

	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastCommentUpdated(updated.OrganizationID, updated)
	}
	return updated, nil
}

func (uc *CommentsUseCase) Delete(ctx context.Context, actorID, commentID uuid.UUID) error {
	c, err := uc.repo.FindByID(ctx, commentID)
	if err != nil {
		return err
	}
	if c == nil || c.IsDeleted() {
		return domain.ErrNotFound
	}

	role, err := uc.memberRepo.FindRole(ctx, c.OrganizationID, actorID)
	if err != nil {
		return domain.ErrForbidden
	}
	isAdmin := role == domain.OrgRoleOwner || role == domain.OrgRoleAdmin
	if !c.CanBeDeletedBy(actorID, isAdmin) {
		return domain.ErrForbidden
	}

	now := uc.clock.Now().UTC()
	if err := uc.repo.SoftDelete(ctx, commentID, actorID, now); err != nil {
		return err
	}

	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastCommentDeleted(c.OrganizationID, c.ItemID, c.ID)
	}
	return nil
}

func (uc *CommentsUseCase) List(ctx context.Context, actorID, itemID uuid.UUID) ([]domain.ItemComment, error) {
	item, err := uc.itemRepo.FindByID(ctx, itemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, domain.ErrNotFound
	}
	if _, err := uc.memberRepo.FindRole(ctx, item.OrganizationID, actorID); err != nil {
		return nil, domain.ErrForbidden
	}

	comments, err := uc.repo.ListByItem(ctx, itemID)
	if err != nil {
		return nil, err
	}
	if len(comments) == 0 {
		return comments, nil
	}

	ids := make([]uuid.UUID, 0, len(comments))
	for _, c := range comments {
		ids = append(ids, c.ID)
	}
	reactions, err := uc.repo.GetReactionsForComments(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range comments {
		if comments[i].IsDeleted() {
			comments[i].Text = ""
			comments[i].MentionedUserIDs = nil
			comments[i].AttachmentURLs = nil
		}
		comments[i].Reactions = reactions[comments[i].ID]
	}
	return comments, nil
}

type AddReactionInput struct {
	ActorID   uuid.UUID
	CommentID uuid.UUID
	Reaction  domain.CommentReactionType
}

func (uc *CommentsUseCase) AddReaction(ctx context.Context, in AddReactionInput) error {
	if !in.Reaction.IsValid() {
		return domain.NewValidationError("invalid reaction")
	}
	c, err := uc.repo.FindByID(ctx, in.CommentID)
	if err != nil {
		return err
	}
	if c == nil || c.IsDeleted() {
		return domain.ErrNotFound
	}
	if _, err := uc.memberRepo.FindRole(ctx, c.OrganizationID, in.ActorID); err != nil {
		return domain.ErrForbidden
	}

	r := &domain.CommentReaction{
		ID:        uuid.New(),
		CommentID: in.CommentID,
		UserID:    in.ActorID,
		Reaction:  in.Reaction,
		CreatedAt: uc.clock.Now().UTC(),
	}
	if err := uc.repo.AddReaction(ctx, r); err != nil {
		return err
	}
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastReactionAdded(c.OrganizationID, r)
	}
	return nil
}

func (uc *CommentsUseCase) RemoveReaction(
	ctx context.Context,
	actorID, commentID uuid.UUID,
	reaction domain.CommentReactionType,
) error {
	if !reaction.IsValid() {
		return domain.NewValidationError("invalid reaction")
	}
	c, err := uc.repo.FindByID(ctx, commentID)
	if err != nil {
		return err
	}
	if c == nil {
		return domain.ErrNotFound
	}
	if _, err := uc.memberRepo.FindRole(ctx, c.OrganizationID, actorID); err != nil {
		return domain.ErrForbidden
	}
	if err := uc.repo.RemoveReaction(ctx, commentID, actorID, reaction); err != nil {
		return err
	}
	if uc.broadcaster != nil {
		uc.broadcaster.BroadcastReactionRemoved(c.OrganizationID, commentID, actorID, reaction)
	}
	return nil
}

func (uc *CommentsUseCase) resolveMentions(
	ctx context.Context,
	orgID uuid.UUID,
	provided []uuid.UUID,
	_ string,
) ([]uuid.UUID, error) {
	if len(provided) == 0 {
		return []uuid.UUID{}, nil
	}
	members, err := uc.memberRepo.ListByOrganization(ctx, orgID)
	if err != nil {
		return nil, err
	}
	allowed := make(map[uuid.UUID]struct{}, len(members))
	for _, m := range members {
		allowed[m.UserID] = struct{}{}
	}
	seen := make(map[uuid.UUID]struct{}, len(provided))
	out := make([]uuid.UUID, 0, len(provided))
	for _, uid := range provided {
		if _, ok := allowed[uid]; !ok {
			continue
		}
		if _, dup := seen[uid]; dup {
			continue
		}
		seen[uid] = struct{}{}
		out = append(out, uid)
	}
	return out, nil
}

func ExtractMentionTokens(text string) []string {
	re := regexp.MustCompile(`@([a-zA-Z0-9_]+)`)
	matches := re.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(matches))
	out := make([]string, 0, len(matches))
	for _, m := range matches {
		if len(m) < 2 {
			continue
		}
		token := m[1]
		if _, dup := seen[token]; dup {
			continue
		}
		seen[token] = struct{}{}
		out = append(out, token)
	}
	return out
}

var _ = time.RFC3339
