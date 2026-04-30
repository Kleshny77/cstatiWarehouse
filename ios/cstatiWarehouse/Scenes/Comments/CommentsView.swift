//
//  CommentsView.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

struct CommentsView: View {

    @Bindable var presenter: CommentsPresenter
    @FocusState private var isInputFocused: Bool

    init(presenter: CommentsPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 0) {
                content
                composer
            }
        }
        .navigationTitle("Комментарии")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { presenter.onAppear() }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK") { presenter.transientErrorMessage = nil }
        } message: {
            if let m = presenter.transientErrorMessage { Text(m) }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch presenter.state {
        case .loading:
            Spacer()
            ProgressView().tint(.white)
            Spacer()

        case .loaded:
            if presenter.comments.isEmpty {
                emptyState
            } else {
                commentsList
            }

        case .failed(let message):
            failedState(message: message)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Пока нет комментариев")
                .foregroundStyle(.white.opacity(0.85))
                .font(font: .bold, size: 17)
            Text("Будьте первым — обсудите эту позицию с командой.")
                .foregroundStyle(.white.opacity(0.6))
                .font(font: .semiBold, size: 13)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func failedState(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Не удалось загрузить комментарии")
                .foregroundStyle(.white.opacity(0.9))
                .font(font: .bold, size: 17)
            Text(message)
                .foregroundStyle(.white.opacity(0.6))
                .font(font: .semiBold, size: 13)
                .multilineTextAlignment(.center)
            Button {
                presenter.reload()
            } label: {
                Text("Повторить")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 15)
                    .frame(width: 180, height: 44)
            }
            .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.pressable)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private var commentsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(rootComments, id: \.id) { root in
                        commentBlock(root: root)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .onChange(of: presenter.comments.count) { _, _ in
                if let last = presenter.comments.last {
                    withAnimation(.easeOut) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var rootComments: [ItemComment] {
        presenter.comments.filter { $0.parentCommentID == nil }
    }

    private func replies(for parent: ItemComment) -> [ItemComment] {
        presenter.comments
            .filter { $0.parentCommentID == parent.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func commentBlock(root: ItemComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            commentRow(root)
            ForEach(replies(for: root), id: \.id) { reply in
                commentRow(reply)
                    .padding(.leading, 28)
            }
        }
        .id(root.id)
    }

    // MARK: - Single comment row

    @ViewBuilder
    private func commentRow(_ comment: ItemComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(presenter.displayName(for: comment.authorUserID))
                    .foregroundStyle(.white.opacity(0.95))
                    .font(font: .bold, size: 14)
                Text(Self.relativeDate(comment.createdAt))
                    .foregroundStyle(.white.opacity(0.5))
                    .font(font: .semiBold, size: 11)
                if comment.isEdited && !comment.isDeleted {
                    Text("(изменено)")
                        .foregroundStyle(.white.opacity(0.45))
                        .font(font: .semiBold, size: 11)
                }
                Spacer()
                if !comment.isDeleted {
                    contextMenuButton(comment)
                }
            }

            if comment.isDeleted {
                Text("Сообщение удалено")
                    .foregroundStyle(.white.opacity(0.45))
                    .font(font: .semiBold, size: 13)
                    .italic()
            } else {
                Text(comment.text)
                    .foregroundStyle(.white.opacity(0.92))
                    .font(font: .semiBold, size: 14)
                    .fixedSize(horizontal: false, vertical: true)

                if !comment.reactions.isEmpty {
                    reactionsRow(comment)
                }

                actionsRow(comment)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func contextMenuButton(_ comment: ItemComment) -> some View {
        Menu {
            if presenter.canEdit(comment) {
                Button {
                    presenter.startEdit(comment)
                    isInputFocused = true
                } label: {
                    Label("Редактировать", systemImage: "pencil")
                }
            }
            if presenter.canDelete(comment) {
                Button(role: .destructive) {
                    presenter.deleteComment(comment)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
            ForEach(CommentReactionType.allCases, id: \.self) { type in
                Button {
                    presenter.toggleReaction(comment: comment, type: type)
                } label: {
                    let mine = presenter.isMyReaction(commentID: comment.id, type: type)
                    Label(
                        mine ? "Снять \(type.emoji)" : "Поставить \(type.emoji)",
                        systemImage: mine ? "minus.circle" : "plus.circle"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.white.opacity(0.7))
                .font(.system(size: 14, weight: .bold))
                .padding(6)
        }
    }

    private func reactionsRow(_ comment: ItemComment) -> some View {
        let counts = comment.reactionCounts
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(counts, id: \.type) { entry in
                    let mine = presenter.isMyReaction(commentID: comment.id, type: entry.type)
                    Button {
                        presenter.toggleReaction(comment: comment, type: entry.type)
                    } label: {
                        HStack(spacing: 4) {
                            Text(entry.type.emoji)
                                .font(.system(size: 13))
                            Text("\(entry.count)")
                                .foregroundStyle(.white.opacity(0.9))
                                .font(font: .bold, size: 11)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(mine ? 0.22 : 0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionsRow(_ comment: ItemComment) -> some View {
        HStack(spacing: 14) {
            Button {
                presenter.startReply(to: comment)
                isInputFocused = true
            } label: {
                Label("Ответить", systemImage: "arrowshape.turn.up.left")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(font: .semiBold, size: 12)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(CommentReactionType.allCases, id: \.self) { type in
                    Button {
                        presenter.toggleReaction(comment: comment, type: type)
                    } label: {
                        Text("\(type.emoji)")
                    }
                }
            } label: {
                Label("Реакция", systemImage: "face.smiling")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(font: .semiBold, size: 12)
            }

            Spacer()
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 6) {
            if let editID = presenter.editingCommentID,
               let target = presenter.comments.first(where: { $0.id == editID }) {
                composerHeader(
                    title: "Редактирование",
                    body: target.text
                )
            } else if let replyID = presenter.replyingToCommentID,
                      let target = presenter.comments.first(where: { $0.id == replyID }) {
                composerHeader(
                    title: "Ответ — \(presenter.displayName(for: target.authorUserID))",
                    body: target.text
                )
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if presenter.inputText.isEmpty {
                        Text("Напишите комментарий…")
                            .foregroundStyle(.white.opacity(0.45))
                            .font(font: .semiBold, size: 14)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                    }
                    TextEditor(text: $presenter.inputText)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .foregroundStyle(.white.opacity(0.95))
                        .font(font: .semiBold, size: 14)
                        .frame(minHeight: 38, maxHeight: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .appGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    presenter.submit()
                    isInputFocused = false
                } label: {
                    Image(systemName: presenter.editingCommentID == nil ? "paperplane.fill" : "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(canSubmit ? 0.95 : 0.4))
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .disabled(!canSubmit)
                .appGlass(in: Circle())
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.0001))
    }

    private func composerHeader(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white.opacity(0.85))
                    .font(font: .bold, size: 12)
                Text(body)
                    .foregroundStyle(.white.opacity(0.55))
                    .font(font: .semiBold, size: 12)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                presenter.cancelComposing()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var canSubmit: Bool {
        !presenter.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !presenter.isSubmitting
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presenter.transientErrorMessage != nil },
            set: { if !$0 { presenter.transientErrorMessage = nil } }
        )
    }

    // MARK: - Helpers

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f
    }()

    private static func relativeDate(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
