import SwiftUI

// MARK: - StylisteView

/// Conversational chat interface with the AI styliste.
/// Context: wardrobe + weather + budget preference injected automatically.
struct StylisteView: View {

    @State private var viewModel = StylisteViewModel()
    @Environment(AppState.self) private var appState
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(EcrinColor.glassStroke)
            messageList
            Divider().background(EcrinColor.glassStroke)
            inputBar
        }
        .background(EcrinColor.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(EcrinColor.gold)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.StylisteUI.aiStylist)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(L10n.StylisteUI.personalizedAdvice)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: EcrinSpacing.sm) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if viewModel.isThinking {
                        ThinkingBubble()
                            .id("thinking")
                    }
                    if let error = viewModel.errorMessage {
                        ErrorBanner(text: error)
                            .id("error")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isThinking) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(spacing: EcrinSpacing.sm) {
            TextField(L10n.StylisteUI.askQuestionPlaceholder, text: $viewModel.inputText, axis: .vertical)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                )
                .focused($inputFocused)
                .onSubmit {
                    Task { await viewModel.sendMessage(appState: appState) }
                }

            Button {
                Task { await viewModel.sendMessage(appState: appState) }
            } label: {
                Image(systemName: viewModel.isThinking ? "ellipsis" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? EcrinColor.textMuted
                            : EcrinColor.background
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? EcrinColor.surface
                            : EcrinColor.gold,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || viewModel.isThinking)
            .animation(.easeInOut(duration: 0.15), value: viewModel.inputText.isEmpty)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .background(EcrinColor.background)
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {

    let message: StylisteMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EcrinColor.gold)
                }
                .alignmentGuide(.bottom) { $0[.bottom] }
            }

            Text(message.text)
                .font(EcrinFont.body)
                .foregroundStyle(isUser ? EcrinColor.background : EcrinColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? EcrinColor.gold : EcrinColor.surface,
                    in: BubbleShape(isUser: isUser)
                )
                .overlay(
                    BubbleShape(isUser: isUser)
                        .strokeBorder(
                            isUser ? Color.clear : EcrinColor.glassStroke,
                            lineWidth: 0.5
                        )
                )

            if !isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - ThinkingBubble

private struct ThinkingBubble: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EcrinColor.gold)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(EcrinColor.textMuted.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(y: phase == i ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.13),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )

            Spacer(minLength: 50)
        }
        .onAppear {
            withAnimation { phase = 0 }
        }
    }
}

// MARK: - ErrorBanner

private struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
            Text(text)
                .font(EcrinFont.caption)
        }
        .foregroundStyle(EcrinColor.textMuted)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BubbleShape

private struct BubbleShape: InsettableShape {
    let isUser: Bool
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = 4
        let inset = insetAmount
        let b = rect.insetBy(dx: inset, dy: inset)

        var path = Path()
        if isUser {
            // Rounded rect with smaller bottom-right corner (tail side)
            path.addRoundedRect(
                in: b,
                cornerRadii: .init(
                    topLeading: r, bottomLeading: r,
                    bottomTrailing: tail, topTrailing: r
                )
            )
        } else {
            path.addRoundedRect(
                in: b,
                cornerRadii: .init(
                    topLeading: tail, bottomLeading: r,
                    bottomTrailing: r, topTrailing: r
                )
            )
        }
        return path
    }

    func inset(by amount: CGFloat) -> BubbleShape {
        BubbleShape(isUser: isUser, insetAmount: insetAmount + amount)
    }
}
