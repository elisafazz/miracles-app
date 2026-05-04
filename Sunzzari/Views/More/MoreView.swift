import SwiftUI

/// 5th tab content. Holds the views that don't fit in the primary 4 tabs
/// (Home / Thoughts / Status / Hub). Mirrors Sunzzari's More-tab pattern.
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
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
                }
                .listRowBackground(Color.miraclesSurface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.miraclesBackground)
            .navigationTitle("More")
        }
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
