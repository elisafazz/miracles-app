import SwiftUI
import UIKit
import UserNotifications

/// 4th tab content. Now also hosts the destinations that previously lived behind
/// the Hub tab (Travel, Gallery, Wine, Restaurants, Activities, On This Day).
struct MoreView: View {
    @State private var notifAuthorized: Bool = true
    @State private var showSettingsPrompt: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Family") {
                    NavigationLink {
                        TravelView()
                    } label: {
                        moreRow(icon: "map.fill", title: "Travel", color: .miraclesAccent)
                    }
                    NavigationLink {
                        GalleryView()
                    } label: {
                        moreRow(icon: "photo.stack.fill", title: "Gallery", color: .miraclesAccent)
                    }
                    NavigationLink {
                        WineHubView()
                    } label: {
                        moreRow(icon: "wineglass.fill", title: "Wine", color: .miraclesAccent)
                    }
                    NavigationLink {
                        RestaurantHubView()
                    } label: {
                        moreRow(icon: "fork.knife", title: "Restaurants", color: .miraclesAccent)
                    }
                    NavigationLink {
                        ActivitiesHubView()
                    } label: {
                        moreRow(icon: "figure.walk", title: "Activities", color: .miraclesAccent)
                    }
                    NavigationLink {
                        OnThisDayView()
                    } label: {
                        moreRow(icon: "calendar.badge.clock", title: "On This Day", color: .miraclesAccent)
                    }
                }
                .listRowBackground(Color.miraclesSurface)

                Section {
                    NavigationLink {
                        BestOfView()
                    } label: {
                        moreRow(icon: "star.fill", title: "Best Of", color: .miraclesAccent)
                    }
                    NavigationLink {
                        SearchView()
                    } label: {
                        moreRow(icon: "magnifyingglass", title: "Search", color: .miraclesSage)
                    }
                    NavigationLink {
                        SettingsView(onComplete: {})
                    } label: {
                        moreRow(icon: "gearshape.fill", title: "Settings", color: .miraclesText)
                    }
                    if !notifAuthorized {
                        Button {
                            showSettingsPrompt = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.miraclesAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications are off")
                                        .font(.system(size: 16, design: .serif))
                                        .foregroundStyle(Color.miraclesText)
                                    Text("Tap to open iOS Settings")
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundStyle(Color.miraclesSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.miraclesSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listRowBackground(Color.miraclesSurface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.miraclesBackground)
            .navigationTitle("More")
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshNotificationStatus() }
                }
            }
            .alert("Open Settings?", isPresented: $showSettingsPrompt) {
                Button("Open Settings") { openSystemSettings() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Notifications are how Miracles tells you when someone posts a story or sends a boop. Enable them in iOS Settings.")
            }
        }
    }

    private func refreshNotificationStatus() async {
        let status = await NotificationService.shared.currentAuthorizationStatus()
        notifAuthorized = (status == .authorized || status == .provisional || status == .ephemeral || status == .notDetermined)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func moreRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color.miraclesText)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
