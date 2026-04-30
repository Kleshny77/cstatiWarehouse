package usecase

import (
	"context"
	"errors"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

func TestExtractMentionTokens_dedupesAndOrders(t *testing.T) {
	toks := ExtractMentionTokens("привет @user1 @user2 @user1 end")
	if len(toks) != 2 {
		t.Fatalf("got %v", toks)
	}
	if toks[0] != "user1" || toks[1] != "user2" {
		t.Fatalf("got %v", toks)
	}
}

func TestExtractMentionTokens_empty(t *testing.T) {
	if ExtractMentionTokens("no mentions") != nil {
		t.Fatal("expected nil")
	}
}

func TestCommentsUseCase_CreateUpdateDeleteList(t *testing.T) {
	ctx := context.Background()
	clk := newFakeClock(time.Date(2026, 3, 1, 10, 0, 0, 0, time.UTC))
	user := uuid.New()
	other := uuid.New()
	orgID := uuid.New()
	itemID := uuid.New()
	addr := "a"

	items := newFakeItemRepo()
	_ = items.Create(ctx, &domain.Item{
		ID:              itemID,
		OrganizationID:  orgID,
		HeldByUserID:    user,
		Name:            "I",
		CategoryName:    "c",
		Quantity:        1,
		Status:          domain.ItemStatusInStock,
		LocationAddress: &addr,
		MeasureUnit:     domain.MeasureUnitPiece,
		CreatedAt:       clk.Now(),
		UpdatedAt:       clk.Now(),
	})
	members := newFakeMemberRepo()
	_ = members.Add(ctx, &domain.OrganizationMember{OrganizationID: orgID, UserID: user, Role: domain.OrgRoleMember, JoinedAt: clk.Now()})
	_ = members.Add(ctx, &domain.OrganizationMember{OrganizationID: orgID, UserID: other, Role: domain.OrgRoleMember, JoinedAt: clk.Now()})

	comments := newFakeCommentRepo()
	uc := NewCommentsUseCase(comments, items, members, clk)

	parent, err := uc.Create(ctx, CreateCommentInput{
		ActorID: user, ItemID: itemID, Text: "корень",
	})
	if err != nil {
		t.Fatal(err)
	}

	reply, err := uc.Create(ctx, CreateCommentInput{
		ActorID: user, ItemID: itemID, Text: "ответ",
		MentionedUserIDs: []uuid.UUID{other, other},
		ParentCommentID: &parent.ID,
	})
	if err != nil || len(reply.MentionedUserIDs) != 1 || reply.MentionedUserIDs[0] != other {
		t.Fatalf("mentions not filtered: %+v err=%v", reply, err)
	}

	if _, err := uc.Create(ctx, CreateCommentInput{
		ActorID: user, ItemID: itemID, Text: "x",
		ParentCommentID: func() *uuid.UUID { id := uuid.New(); return &id }(),
	}); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("invalid parent: %v", err)
	}

	if _, err := uc.Update(ctx, UpdateCommentInput{
		ActorID: other, CommentID: parent.ID, Text: "hack",
	}); err != domain.ErrForbidden {
		t.Fatalf("non-author update: %v", err)
	}

	updated, err := uc.Update(ctx, UpdateCommentInput{
		ActorID: user, CommentID: parent.ID, Text: "правка",
	})
	if err != nil || updated.Text != "правка" {
		t.Fatal(err)
	}

	if err := uc.Delete(ctx, other, parent.ID); err != domain.ErrForbidden {
		t.Fatalf("non-admin delete others: %v", err)
	}
	if err := uc.Delete(ctx, user, parent.ID); err != nil {
		t.Fatal(err)
	}

	list, err := uc.List(ctx, user, itemID)
	if err != nil || len(list) != 2 {
		t.Fatalf("list: %+v err=%v", list, err)
	}
	var deleted *domain.ItemComment
	for i := range list {
		if list[i].IsDeleted() {
			deleted = &list[i]
			break
		}
	}
	if deleted == nil || deleted.Text != "" {
		t.Fatalf("deleted sanitizer failed: %+v", deleted)
	}
}

func TestCommentsUseCase_Reactions(t *testing.T) {
	ctx := context.Background()
	clk := newFakeClock(time.Date(2026, 3, 1, 10, 0, 0, 0, time.UTC))
	user := uuid.New()
	orgID := uuid.New()
	itemID := uuid.New()
	addr := "a"

	items := newFakeItemRepo()
	_ = items.Create(ctx, &domain.Item{
		ID: itemID, OrganizationID: orgID, HeldByUserID: user,
		Name: "I", CategoryName: "c", Quantity: 1, Status: domain.ItemStatusInStock,
		LocationAddress: &addr, MeasureUnit: domain.MeasureUnitPiece,
		CreatedAt: clk.Now(), UpdatedAt: clk.Now(),
	})
	members := newFakeMemberRepo()
	_ = members.Add(ctx, &domain.OrganizationMember{OrganizationID: orgID, UserID: user, Role: domain.OrgRoleMember, JoinedAt: clk.Now()})
	comments := newFakeCommentRepo()
	uc := NewCommentsUseCase(comments, items, members, clk)

	c, err := uc.Create(ctx, CreateCommentInput{ActorID: user, ItemID: itemID, Text: "hi"})
	if err != nil {
		t.Fatal(err)
	}
	if err := uc.AddReaction(ctx, AddReactionInput{
		ActorID: user, CommentID: c.ID, Reaction: domain.ReactionThumbsUp,
	}); err != nil {
		t.Fatal(err)
	}
	if err := uc.AddReaction(ctx, AddReactionInput{
		ActorID: user, CommentID: c.ID, Reaction: domain.CommentReactionType("bad"),
	}); err == nil {
		t.Fatal("invalid reaction")
	}
	if err := uc.RemoveReaction(ctx, user, c.ID, domain.ReactionThumbsUp); err != nil {
		t.Fatal(err)
	}
}

// fakeCommentRepo — in-memory реализация CommentRepository для тестов.

type fakeCommentRepo struct {
	mu        sync.Mutex
	comments  map[uuid.UUID]*domain.ItemComment
	reactions map[uuid.UUID][]domain.CommentReaction
}

func newFakeCommentRepo() *fakeCommentRepo {
	return &fakeCommentRepo{
		comments:  map[uuid.UUID]*domain.ItemComment{},
		reactions: map[uuid.UUID][]domain.CommentReaction{},
	}
}

func (r *fakeCommentRepo) Create(ctx context.Context, c *domain.ItemComment) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	clone := *c
	r.comments[c.ID] = &clone
	return nil
}

func (r *fakeCommentRepo) UpdateText(
	ctx context.Context,
	commentID uuid.UUID,
	newText string,
	mentionedUserIDs []uuid.UUID,
	editedBy uuid.UUID,
	now time.Time,
) (*domain.ItemComment, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	c, ok := r.comments[commentID]
	if !ok || c.IsDeleted() {
		return nil, domain.ErrNotFound
	}
	c.Text = newText
	c.MentionedUserIDs = mentionedUserIDs
	c.UpdatedAt = now
	c.EditedAt = &now
	out := *c
	r.comments[commentID] = c
	return &out, nil
}

func (r *fakeCommentRepo) SoftDelete(ctx context.Context, commentID, deletedBy uuid.UUID, now time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	c, ok := r.comments[commentID]
	if !ok {
		return domain.ErrNotFound
	}
	c.DeletedAt = &now
	c.DeletedByUserID = &deletedBy
	r.comments[commentID] = c
	return nil
}

func (r *fakeCommentRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.ItemComment, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	c, ok := r.comments[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	out := *c
	return &out, nil
}

func (r *fakeCommentRepo) ListByItem(ctx context.Context, itemID uuid.UUID) ([]domain.ItemComment, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []domain.ItemComment
	for _, c := range r.comments {
		if c.ItemID == itemID {
			out = append(out, *c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out, nil
}

func (r *fakeCommentRepo) AddReaction(ctx context.Context, reaction *domain.CommentReaction) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.reactions[reaction.CommentID] = append(r.reactions[reaction.CommentID], *reaction)
	return nil
}

func (r *fakeCommentRepo) RemoveReaction(ctx context.Context, commentID, userID uuid.UUID, reaction domain.CommentReactionType) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	slice := r.reactions[commentID]
	var kept []domain.CommentReaction
	for _, x := range slice {
		if x.UserID == userID && x.Reaction == reaction {
			continue
		}
		kept = append(kept, x)
	}
	r.reactions[commentID] = kept
	return nil
}

func (r *fakeCommentRepo) GetReactions(ctx context.Context, commentID uuid.UUID) ([]domain.CommentReaction, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := append([]domain.CommentReaction(nil), r.reactions[commentID]...)
	return out, nil
}

func (r *fakeCommentRepo) GetReactionsForComments(ctx context.Context, commentIDs []uuid.UUID) (map[uuid.UUID][]domain.CommentReaction, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make(map[uuid.UUID][]domain.CommentReaction, len(commentIDs))
	for _, id := range commentIDs {
		out[id] = append([]domain.CommentReaction(nil), r.reactions[id]...)
	}
	return out, nil
}
