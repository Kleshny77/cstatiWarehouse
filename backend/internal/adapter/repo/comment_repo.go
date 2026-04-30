package repo

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type CommentRepo struct {
	pool *pgxpool.Pool
}

func NewCommentRepo(pool *pgxpool.Pool) *CommentRepo {
	return &CommentRepo{pool: pool}
}

const commentColumns = `id, item_id, organization_id, text, author_user_id, mentioned_user_ids, attachment_urls,
	parent_comment_id, created_at, updated_at, edited_at, deleted_at, deleted_by_user_id`

func (r *CommentRepo) Create(ctx context.Context, c *domain.ItemComment) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO item_comments
			(id, item_id, organization_id, text, author_user_id, mentioned_user_ids, attachment_urls,
			 parent_comment_id, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
	`,
		c.ID, c.ItemID, c.OrganizationID, c.Text, c.AuthorUserID,
		uuidsToArray(c.MentionedUserIDs), stringsOrEmpty(c.AttachmentURLs),
		c.ParentCommentID, c.CreatedAt, c.UpdatedAt,
	)
	return err
}

func (r *CommentRepo) UpdateText(
	ctx context.Context,
	commentID uuid.UUID,
	newText string,
	mentionedUserIDs []uuid.UUID,
	editedBy uuid.UUID,
	now time.Time,
) (*domain.ItemComment, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var previousText string
	var deletedAt *time.Time
	if err := tx.QueryRow(ctx, `
		SELECT text, deleted_at FROM item_comments WHERE id = $1 FOR UPDATE
	`, commentID).Scan(&previousText, &deletedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	if deletedAt != nil {
		return nil, domain.ErrNotFound
	}

	if previousText != newText {
		if _, err := tx.Exec(ctx, `
			INSERT INTO comment_edit_history (comment_id, previous_text, edited_by_user_id, edited_at)
			VALUES ($1, $2, $3, $4)
		`, commentID, previousText, editedBy, now); err != nil {
			return nil, err
		}
	}

	if _, err := tx.Exec(ctx, `
		UPDATE item_comments SET
			text = $2,
			mentioned_user_ids = $3,
			updated_at = $4,
			edited_at = $4
		WHERE id = $1
	`, commentID, newText, uuidsToArray(mentionedUserIDs), now); err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.FindByID(ctx, commentID)
}

func (r *CommentRepo) SoftDelete(ctx context.Context, commentID, deletedBy uuid.UUID, now time.Time) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE item_comments
		SET deleted_at = $2, deleted_by_user_id = $3, updated_at = $2
		WHERE id = $1 AND deleted_at IS NULL
	`, commentID, now, deletedBy)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *CommentRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.ItemComment, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+commentColumns+` FROM item_comments WHERE id = $1`, id)
	return scanComment(row)
}

func (r *CommentRepo) ListByItem(ctx context.Context, itemID uuid.UUID) ([]domain.ItemComment, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+commentColumns+`
		FROM item_comments
		WHERE item_id = $1
		ORDER BY created_at ASC
	`, itemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.ItemComment
	for rows.Next() {
		c, err := scanComment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (r *CommentRepo) AddReaction(ctx context.Context, reaction *domain.CommentReaction) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO comment_reactions (id, comment_id, user_id, reaction, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (comment_id, user_id, reaction) DO NOTHING
	`, reaction.ID, reaction.CommentID, reaction.UserID, string(reaction.Reaction), reaction.CreatedAt)
	return err
}

func (r *CommentRepo) RemoveReaction(
	ctx context.Context,
	commentID, userID uuid.UUID,
	reaction domain.CommentReactionType,
) error {
	_, err := r.pool.Exec(ctx, `
		DELETE FROM comment_reactions
		WHERE comment_id = $1 AND user_id = $2 AND reaction = $3
	`, commentID, userID, string(reaction))
	return err
}

func (r *CommentRepo) GetReactions(ctx context.Context, commentID uuid.UUID) ([]domain.CommentReaction, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, comment_id, user_id, reaction, created_at
		FROM comment_reactions
		WHERE comment_id = $1
		ORDER BY created_at ASC
	`, commentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.CommentReaction
	for rows.Next() {
		var r domain.CommentReaction
		var rawReaction string
		if err := rows.Scan(&r.ID, &r.CommentID, &r.UserID, &rawReaction, &r.CreatedAt); err != nil {
			return nil, err
		}
		r.Reaction = domain.CommentReactionType(rawReaction)
		out = append(out, r)
	}
	return out, rows.Err()
}

func (r *CommentRepo) GetReactionsForComments(
	ctx context.Context,
	commentIDs []uuid.UUID,
) (map[uuid.UUID][]domain.CommentReaction, error) {
	out := make(map[uuid.UUID][]domain.CommentReaction, len(commentIDs))
	if len(commentIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, comment_id, user_id, reaction, created_at
		FROM comment_reactions
		WHERE comment_id = ANY($1)
		ORDER BY created_at ASC
	`, commentIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var rc domain.CommentReaction
		var rawReaction string
		if err := rows.Scan(&rc.ID, &rc.CommentID, &rc.UserID, &rawReaction, &rc.CreatedAt); err != nil {
			return nil, err
		}
		rc.Reaction = domain.CommentReactionType(rawReaction)
		out[rc.CommentID] = append(out[rc.CommentID], rc)
	}
	return out, rows.Err()
}

func scanComment(row pgx.Row) (*domain.ItemComment, error) {
	var c domain.ItemComment
	var mentioned []uuid.UUID
	var attachments []string
	if err := row.Scan(
		&c.ID, &c.ItemID, &c.OrganizationID, &c.Text, &c.AuthorUserID,
		&mentioned, &attachments,
		&c.ParentCommentID, &c.CreatedAt, &c.UpdatedAt, &c.EditedAt, &c.DeletedAt, &c.DeletedByUserID,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	c.MentionedUserIDs = mentioned
	c.AttachmentURLs = attachments
	return &c, nil
}

func uuidsToArray(in []uuid.UUID) []uuid.UUID {
	if in == nil {
		return []uuid.UUID{}
	}
	return in
}

func stringsOrEmpty(in []string) []string {
	if in == nil {
		return []string{}
	}
	return in
}
