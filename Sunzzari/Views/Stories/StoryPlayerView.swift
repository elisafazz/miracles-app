import SwiftUI

struct StoryPlayerView: View {
    let stories: [StoryPost]
    let person: StoryPost.Person
    let onDismiss: () -> Void
    var onReelComplete: (() -> Void)? = nil
    var onRequestPrevious: (() -> Void)? = nil
    var isActive: Bool = true

    @State private var currentIndex: Int = 0
    @State private var progress: Double = 0
    @State private var isPaused: Bool = false
    @State private var prefetchedURLs: Set<URL> = []

    // Interaction
    @State private var commentText = ""
    @State private var isComposing = false
    @State private var showEmojiPicker = false
    @State private var floatingEmojis: [FloatingEmojiItem] = []
    @State private var ephemeralComments: [EphemeralComment] = []
    @FocusState private var commentFieldFocused: Bool

    // Persisted reactions — overlays the loaded story data with any optimistic local additions
    @State private var pendingReactions: [String: [StoryPost.Reaction]] = [:]

    private let storyDuration: TimeInterval = 5.0
    private let tickInterval: TimeInterval = 0.05
    private let headerTapInset: CGFloat = 60

    private static let postedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func relativeTimeLabel(for date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)
        if elapsed >= 0 && elapsed < 3600 {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: now)
        }
        let cal = Calendar.current
        let timeStr = Self.postedAtFormatter.string(from: date)
        if cal.isDateInToday(date) { return timeStr }
        if cal.isDateInYesterday(date) { return "Yesterday \(timeStr)" }
        return timeStr
    }

    private var currentStory: StoryPost? {
        guard stories.indices.contains(currentIndex) else { return nil }
        return stories[currentIndex]
    }

    private var viewer: StoryPost.Person {
        switch AppIdentity.current {
        case .mom:    return .mom
        case .sister: return .sister
        default:      return .elisa
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo player + overlays (ignores keyboard so it stays full-size)
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let currentStory {
                        AsyncImage(url: currentStory.fullURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .blur(radius: 32)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            } else { Color.black }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped().ignoresSafeArea()

                        AsyncImage(url: currentStory.fullURL) { phase in
                            switch phase {
                            case .empty:   ProgressView().tint(.white)
                            case .success(let image): image.resizable().scaledToFit()
                            case .failure:
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 32, design: .serif))
                                    Text("Couldn't load photo")
                                        .font(.system(.subheadline, design: .serif))
                                }
                                .foregroundStyle(.white.opacity(0.7))
                            @unknown default: EmptyView()
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                    }

                    // Reactions row + Caption — stacked just above the interaction bar
                    if let story = currentStory {
                        let reactions = displayReactions(for: story)
                        VStack(spacing: 6) {
                            Spacer()
                            // Persisted reactions strip
                            if !reactions.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(reactions) { reaction in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: reaction.person.colorHex))
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Text(String(reaction.person.displayName.prefix(1)))
                                                        .font(.system(size: 8, weight: .bold, design: .serif))
                                                        .foregroundStyle(.white)
                                                )
                                            Text(reaction.emoji)
                                                .font(.system(size: 16))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: Capsule())
                                    }
                                }
                            }
                            // Caption
                            if !story.caption.isEmpty {
                                Text(story.caption)
                                    .font(.system(.body, design: .serif, weight: .medium))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 110)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                    }

                    // Tap zones — bottom gap leaves room for the interaction bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geo.safeAreaInsets.top + headerTapInset)
                        HStack(spacing: 0) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { commentFieldFocused = false; goBack() }
                                .accessibilityLabel("Previous story")
                                .accessibilityAddTraits(.isButton)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { commentFieldFocused = false; advance() }
                                .accessibilityLabel("Next story")
                                .accessibilityAddTraits(.isButton)
                        }
                        .padding(.bottom, 80)
                    }

                    // Floating emoji animations
                    ForEach(floatingEmojis) { item in
                        FloatingEmojiView(emoji: item.emoji) {
                            floatingEmojis.removeAll { $0.id == item.id }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 120)
                        .allowsHitTesting(false)
                    }

                    // Top: progress bars + author header
                    VStack(spacing: 10) {
                        progressBars
                        headerRow
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                }
                .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 50) {
                } onPressingChanged: { pressing in
                    isPaused = pressing
                }
                .task(id: PlayKey(index: currentIndex, active: isActive)) {
                    guard isActive else { return }
                    if let story = currentStory {
                        SeenStoriesStore.shared.markSeen(story.id)
                        NotificationCenter.default.post(name: .storiesDidMarkSeen, object: nil)
                    }
                    await runProgressLoop()
                }
                .statusBarHidden(true)
            }
            .ignoresSafeArea(.keyboard) // photo stays full-size when keyboard appears

            // Interaction bar — sits at bottom, slides up with keyboard naturally
            interactionBar
        }
        .onChange(of: isComposing) { _, composing in isPaused = composing }
        .sheet(isPresented: $showEmojiPicker) { emojiPickerSheet }
    }

    // MARK: - Interaction bar

    private var interactionBar: some View {
        VStack(spacing: 0) {
            // Ephemeral comments list (this session only)
            if !ephemeralComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ephemeralComments) { comment in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color(hex: comment.person.colorHex))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text(String(comment.person.rawValue.prefix(1)))
                                        .font(.system(size: 9, weight: .bold, design: .serif))
                                        .foregroundStyle(.white)
                                )
                            Text(comment.text)
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }

            // Input row
            HStack(spacing: 10) {
                TextField("Add a comment...", text: $commentText)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.primary)
                    .focused($commentFieldFocused)
                    .onChange(of: commentFieldFocused) { _, focused in
                        withAnimation(.easeInOut(duration: 0.2)) { isComposing = focused }
                    }
                    .submitLabel(.send)
                    .onSubmit { sendComment() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { commentFieldFocused = false }
                                .foregroundStyle(Color.miraclesAccent)
                        }
                    }

                if isComposing {
                    Button {
                        sendComment()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(commentText.isEmpty ? Color.white.opacity(0.3) : Color.white)
                    }
                    .disabled(commentText.isEmpty)
                } else {
                    Button { Task { await sendReaction("❤️") } } label: {
                        Text("❤️").font(.system(size: 26))
                    }
                }

                Button { showEmojiPicker = true } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        if value.translation.height > 0 { commentFieldFocused = false }
                    }
            )
        }
    }

    // MARK: - Emoji picker sheet

    private var emojiPickerSheet: some View {
        let emojis = [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🩷", "🤍", "🖤",
            "🔥", "✨", "💯", "🎉", "⭐", "🌟", "🌈", "🌸", "🌺",
            "😂", "😮", "🥹", "😍", "🤩", "😎", "🥳", "😭", "🥺",
            "👏", "🙏", "🫶", "💪", "🤝", "🫂", "🤗", "😘", "💋",
            "🐶", "🐱", "🦋", "🌊", "⛰️", "🏠", "🍷", "🍰", "☕",
            "🎵", "🎶", "📸", "✈️", "🌙", "☀️", "❄️", "🫀", "‼️"
        ]
        return NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 8),
                    spacing: 16
                ) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            Task { await sendReaction(emoji) }
                            showEmojiPicker = false
                        } label: {
                            Text(emoji).font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showEmojiPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func displayReactions(for story: StoryPost) -> [StoryPost.Reaction] {
        let fetched = story.reactions
        let pending = pendingReactions[story.id] ?? []
        var merged: [StoryPost.Person: StoryPost.Reaction] = Dictionary(
            uniqueKeysWithValues: fetched.map { ($0.person, $0) }
        )
        for r in pending { merged[r.person] = r }
        return merged.values.sorted { $0.person.rawValue < $1.person.rawValue }
    }

    private func sendReaction(_ emoji: String) async {
        addFloatingEmoji(emoji)
        guard let story = currentStory else { return }
        // Optimistic update
        var updated = pendingReactions[story.id] ?? []
        updated.removeAll { $0.person == viewer }
        updated.append(StoryPost.Reaction(person: viewer, emoji: emoji))
        pendingReactions[story.id] = updated
        // Persist to Notion + notify others
        let name = viewer.displayName
        async let notif: () = { try? await BoopService.shared.send(
            message: emoji,
            notificationTitle: "\(name) reacted \(emoji) to your story"
        )}()
        async let persist: () = { try? await NotionService.shared.addStoryReaction(
            storyID: story.id, person: viewer, emoji: emoji
        )}()
        _ = await (notif, persist)
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let comment = EphemeralComment(person: viewer, text: text)
        withAnimation { ephemeralComments.append(comment) }
        let name = viewer.displayName
        Task {
            try? await BoopService.shared.send(
                message: text,
                notificationTitle: "\(name) commented on your story"
            )
        }
        commentText = ""
        commentFieldFocused = false
    }

    private func addFloatingEmoji(_ emoji: String) {
        let item = FloatingEmojiItem(emoji: emoji)
        floatingEmojis.append(item)
    }

    // MARK: - Top header

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(stories.indices, id: \.self) { i in
                GeometryReader { rowGeo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: rowGeo.size.width * fillFraction(for: i))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: person.colorHex))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(person.displayName.prefix(1)))
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(person.displayName)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)
                if let story = currentStory {
                    HStack(spacing: 4) {
                        Text(relativeTimeLabel(for: story.postedAt))
                        if let location = story.location, !location.isEmpty {
                            Text("•")
                            Text(location)
                        }
                    }
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
        }
    }

    private func fillFraction(for i: Int) -> Double {
        if i < currentIndex { return 1.0 }
        if i == currentIndex { return progress }
        return 0
    }

    // MARK: - Playback

    @MainActor
    private func runProgressLoop() async {
        if progress >= 1.0 { progress = 0 }
        let anchor = progress
        let startDate = Date().addingTimeInterval(-anchor * storyDuration)
        var pausedAt: Date? = nil
        var totalPaused: TimeInterval = 0
        var didPrefetch = anchor >= 0.5
        while progress < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
            if Task.isCancelled { return }
            if isPaused {
                if pausedAt == nil { pausedAt = Date() }
                continue
            } else if let p = pausedAt {
                totalPaused += Date().timeIntervalSince(p)
                pausedAt = nil
            }
            let elapsed = Date().timeIntervalSince(startDate) - totalPaused
            progress = min(1.0, elapsed / storyDuration)
            if !didPrefetch, progress >= 0.5 {
                didPrefetch = true
                prefetchNextImage()
            }
        }
        if !Task.isCancelled { advance() }
    }

    private func prefetchNextImage() {
        guard currentIndex + 1 < stories.count,
              let url = stories[currentIndex + 1].fullURL,
              !prefetchedURLs.contains(url) else { return }
        prefetchedURLs.insert(url)
        Task.detached { _ = try? await URLSession.shared.data(from: url) }
    }

    private func advance() {
        progress = 0
        if currentIndex + 1 < stories.count {
            currentIndex += 1
        } else {
            (onReelComplete ?? onDismiss)()
        }
    }

    private func goBack() {
        if currentIndex == 0 {
            if let onRequestPrevious { onRequestPrevious() }
            else { progress = 0 }
        } else {
            progress = 0
            currentIndex -= 1
        }
    }

    // MARK: - Supporting types

    private struct PlayKey: Hashable {
        let index: Int
        let active: Bool
    }

    private struct FloatingEmojiItem: Identifiable {
        let id = UUID()
        let emoji: String
    }

    private struct EphemeralComment: Identifiable {
        let id = UUID()
        let person: StoryPost.Person
        let text: String
    }
}

// MARK: - Floating emoji animation

private struct FloatingEmojiView: View {
    let emoji: String
    let onFinish: () -> Void

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Text(emoji)
            .font(.system(size: 72))
            .scaleEffect(scale)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    scale = 1.15
                }
                withAnimation(.easeOut(duration: 1.6).delay(0.15)) {
                    offset = -220
                    opacity = 0
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_900_000_000)
                    onFinish()
                }
            }
    }
}
