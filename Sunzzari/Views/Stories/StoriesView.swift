import SwiftUI

/// The Stories tab embeds the story player inline so it runs as the
/// tab's main content. The + (compose) and own-story circle float on
/// top via overlay. Tapping X or Close in the end-of-loop overlay
/// navigates to the Home tab.
struct StoriesView: View {
    @Binding var selectedTab: Int

    @State private var stories: [StoryPost] = []
    @State private var showCompose = false
    @State private var playerStartingPerson: StoryPost.Person = .elisa
    @State private var playerNonce: UUID = UUID()
    @State private var yearRecapStories: [StoryPost] = []
    @State private var yearRecapYear: Int = 0
    @State private var showYearRecap = false

    private static let yearRecapShownKey = "miracles_year_recap_shown"

    private var currentPerson: StoryPost.Person {
        switch AppIdentity.current {
        case .mom:    return .mom
        case .sister: return .sister
        default:      return .elisa
        }
    }

    // Unseen partners first (by latest post), seen partners next, self last.
    private var personsWithStories: [StoryPost.Person] {
        let me = currentPerson
        let others = StoryPost.Person.allCases.filter { p in
            p != me && stories.contains { $0.person == p }
        }
        let unseenOthers = others.filter { p in
            SeenStoriesStore.shared.unseenCount(in: stories.filter { $0.person == p }) > 0
        }.sorted { latestDate(for: $0) > latestDate(for: $1) }
        let seenOthers = others.filter { p in
            SeenStoriesStore.shared.unseenCount(in: stories.filter { $0.person == p }) == 0
        }.sorted { latestDate(for: $0) > latestDate(for: $1) }
        var result = unseenOthers + seenOthers
        if stories.contains(where: { $0.person == me }) { result.append(me) }
        return result
    }

    private var hasOwnStories: Bool {
        stories.contains { $0.person == currentPerson }
    }

    var body: some View {
        ZStack {
            if personsWithStories.isEmpty {
                Color.miraclesBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("No stories yet")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                    Text("Tap + to share a moment")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary.opacity(0.7))
                }
            } else {
                // Player runs inline as the tab content. Keyed on playerNonce so
                // tapping the own-story bubble resets it to start from self.
                StoryTrayView(
                    persons: personsWithStories,
                    startingPerson: playerStartingPerson,
                    reelFor: { person in
                        stories.filter { $0.person == person }.sorted { $0.postedAt > $1.postedAt }
                    },
                    onDismiss: { selectedTab = 0 }
                )
                .id(playerNonce)
            }
        }
        // Compose (+) and own-stories bubble float on top of the player.
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Button { showCompose = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.miraclesAccent)
                        .clipShape(Circle())
                        .shadow(color: Color.miraclesAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                }

                if hasOwnStories {
                    Button { jumpToOwnStories() } label: {
                        Circle()
                            .fill(Color(hex: currentPerson.colorHex))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(currentPerson.rawValue.prefix(1)))
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 100) // clear the tab bar
            .padding(.trailing, 24)
        }
        .sheet(isPresented: $showCompose) {
            StoryComposeView { newPost in
                stories.insert(newPost, at: 0)
            }
        }
        .fullScreenCover(isPresented: $showYearRecap) {
            NavigationStack {
                YearRecapView(year: yearRecapYear, stories: yearRecapStories)
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .storiesDidMarkSeen)) { _ in
            stories = stories
        }
    }

    // Force the player to rebuild starting from own reel.
    private func jumpToOwnStories() {
        playerStartingPerson = currentPerson
        playerNonce = UUID()
    }

    private func latestDate(for person: StoryPost.Person) -> Date {
        stories.filter { $0.person == person }
            .max(by: { $0.postedAt < $1.postedAt })?.postedAt ?? .distantPast
    }

    private func load() async {
        if let cached = NotionService.shared.storiesActiveDiskCache() {
            stories = cached
            playerStartingPerson = personsWithStories.first ?? currentPerson
        }
        do {
            stories = try await NotionService.shared.fetchActiveStories(force: true)
            if playerStartingPerson == currentPerson, let first = personsWithStories.first {
                playerStartingPerson = first
            }
        } catch { }
        await maybePresentYearRecap()
    }

    private func maybePresentYearRecap() async {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        guard comps.month == 12, comps.day == 31, let year = comps.year else { return }
        let lastShown = UserDefaults.standard.integer(forKey: Self.yearRecapShownKey)
        guard lastShown != year else { return }
        do {
            let yearStories = try await NotionService.shared.fetchArchiveStories(year: year)
            guard !yearStories.isEmpty else { return }
            yearRecapStories = yearStories
            yearRecapYear = year
            showYearRecap = true
            UserDefaults.standard.set(year, forKey: Self.yearRecapShownKey)
        } catch {
            #if DEBUG
            print("[YearRecap] fetch failed:", error.localizedDescription)
            #endif
        }
    }
}
