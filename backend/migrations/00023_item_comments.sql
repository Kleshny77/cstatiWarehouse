-- +goose Up
-- +goose StatementBegin

-- item_comments: обсуждения и заметки к позициям склада в рамках организации.
CREATE TABLE item_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items (id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,

    text TEXT NOT NULL,

    author_user_id UUID NOT NULL REFERENCES users (id),

    -- Перечень упомянутых пользователей: фронт извлекает @-нотацию и сразу резолвит в UUID
    -- (только участники организации). NOT NULL гарантируется DEFAULT '{}'.
    mentioned_user_ids UUID[] NOT NULL DEFAULT '{}',

    -- URL-адреса аттачей (картинок/файлов), уже загруженных через /uploads.
    attachment_urls TEXT[] NOT NULL DEFAULT '{}',

    -- Threading (необязательное поле; ON DELETE CASCADE удаляет ответы при удалении родителя).
    parent_comment_id UUID REFERENCES item_comments (id) ON DELETE CASCADE,

    -- Lifecycle
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id UUID REFERENCES users (id),

    CONSTRAINT item_comments_text_length CHECK (length(text) > 0 AND length(text) <= 5000),
    CONSTRAINT item_comments_text_not_blank CHECK (length(btrim(text)) > 0)
);

-- Индексы для основных сценариев
CREATE INDEX idx_item_comments_item_created
    ON item_comments (item_id, created_at);

CREATE INDEX idx_item_comments_organization
    ON item_comments (organization_id, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_item_comments_author
    ON item_comments (author_user_id);

-- GIN-индекс по упомянутым пользователям — для быстрого "@me"-фида.
CREATE INDEX idx_item_comments_mentioned_users
    ON item_comments USING GIN (mentioned_user_ids);

-- comment_reactions: эмодзи-реакции (👍 / ❤️ / etc.) на комментарии.
-- Пара (comment_id, user_id, reaction) уникальна, чтобы один и тот же пользователь
-- не мог поставить одну и ту же реакцию дважды.
CREATE TABLE comment_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES item_comments (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    reaction TEXT NOT NULL CHECK (reaction IN ('thumbs_up', 'thumbs_down', 'heart', 'laugh', 'party', 'eyes')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_comment_reactions
    ON comment_reactions (comment_id, user_id, reaction);

CREATE INDEX idx_comment_reactions_comment
    ON comment_reactions (comment_id);

-- comment_edit_history: аудит изменений текста (опционально, но полезно для прозрачности).
CREATE TABLE comment_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES item_comments (id) ON DELETE CASCADE,
    previous_text TEXT NOT NULL,
    edited_by_user_id UUID NOT NULL REFERENCES users (id),
    edited_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_comment_edit_history_comment
    ON comment_edit_history (comment_id, edited_at DESC);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS comment_edit_history;
DROP TABLE IF EXISTS comment_reactions;
DROP TABLE IF EXISTS item_comments;
-- +goose StatementEnd
