import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showIdentitySetup = false
    @State private var showWeeklyBestOf = false
    @State private var showInbox = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem {
                        Label("Home", systemImage: "sparkles")
                    }
                    .tag(0)

                NavigationStack { ThoughtsView() }
                    .tabItem {
                        Label("Thoughts", systemImage: "lightbulb.fill")
                    }
                    .tag(1)

                StoriesView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Stories", systemImage: "circle.dashed.inset.filled")
                    }
                    .tag(2)

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(3)
            }
            .tint(.miraclesAccent)
            .fontDesign(.serif)

            // Warm ambient glow — two-point radial system
            GeometryReader { geo in
                ZStack {
                    RadialGradient(
                        colors: [Color(hex: "#D4815B").opacity(0.10), .clear],
                        center: .init(x: 0.0, y: 1.0),
                        startRadius: 0,
                        endRadius: geo.size.height * 0.55
                    )
                    RadialGradient(
                        colors: [Color(hex: "#F97316").opacity(0.05), .clear],
                        center: .init(x: 1.0, y: 0.0),
                        startRadius: 0,
                        endRadius: geo.size.width * 0.6
                    )
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $showIdentitySetup) {
            SettingsView(onComplete: { showIdentitySetup = false })
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showWeeklyBestOf) {
            WeeklyBestOfInputView()
        }
        .sheet(isPresented: $showInbox) {
            NotificationInboxView { entry in
                switch entry.type {
                case .boop:
                    break
                case .weeklyBestOf:
                    showWeeklyBestOf = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeeklyBestOf)) { _ in
            showWeeklyBestOf = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInbox)) { _ in
            showInbox = true
        }
        .task {
            if AppIdentity.current == nil {
                showIdentitySetup = true
            }
            // Drain cold-launch deep-link buffer — handles the race where didReceive
            // posted before onReceive was attached (notification tapped from killed state).
            if AppDelegate.pendingWeeklyBestOfDeepLink {
                AppDelegate.pendingWeeklyBestOfDeepLink = false
                showWeeklyBestOf = true
            }
            await BoopService.shared.checkForBoops()
            await syncWeeklyBestOfFromDelivered()
            await syncBadgeFromInbox()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await BoopService.shared.checkForBoops()
                    await syncWeeklyBestOfFromDelivered()
                    await DailySetupService.shared.runDailySetup()
                    await syncBadgeFromInbox()
                }
            }
        }
    }

    /// Drives the iOS app icon badge from the in-app inbox unread count.
    private func syncBadgeFromInbox() async {
        let count = NotificationInboxService.shared.unreadCount
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Recovery path: if the Sunday 8pm weekly notification fired while the app was
    /// killed, willPresent never ran. On next foreground, scan delivered notifications
    /// for the weekly identifier and append an inbox entry if not already present.
    private func syncWeeklyBestOfFromDelivered() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let weekly = delivered.first { $0.request.identifier == "miracles-weekly-bestof" }
        guard weekly != nil else { return }
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekID = "miracles-weekly-bestof-\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        NotificationInboxService.shared.append(
            id: weekID,
            type: .weeklyBestOf,
            title: "Weekly Best Of",
            subtitle: "Any highlights from the week?"
        )
    }
}
