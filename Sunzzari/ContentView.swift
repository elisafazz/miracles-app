import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showIdentitySetup = false
    @State private var showWeeklyBestOf = false
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
        .onReceive(NotificationCenter.default.publisher(for: .openWeeklyBestOf)) { _ in
            showWeeklyBestOf = true
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
                    try? await UNUserNotificationCenter.current().setBadgeCount(delivered.count)
                    await BoopService.shared.checkForBoops()
                    await DailySetupService.shared.runDailySetup()
                }
            }
        }
    }
}
