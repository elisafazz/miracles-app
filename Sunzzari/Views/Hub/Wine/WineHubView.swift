import SwiftUI

struct WineHubView: View {
    @State private var showAdd = false
    @State private var showPicker = false

    var body: some View {
        ZStack {
            Color.miraclesBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                SerifNavHeader("Wine")

                List {
                    Button { showAdd = true } label: {
                        hubCell(icon: "plus.circle", title: "Add Wine", subtitle: "Log a bottle")
                    }
                    .listRowBackground(Color.miraclesSurface)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    Button { showPicker = true } label: {
                        hubCell(icon: "wand.and.stars", iconColor: .miraclesAccent, title: "Wine Picker", subtitle: "AI helps pick a wine")
                    }
                    .listRowBackground(Color.miraclesSurface)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) { AddWineView() }
        .sheet(isPresented: $showPicker) { WinePickerView() }
    }

    private func hubCell(icon: String, iconColor: Color = .miraclesAccent, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.miraclesText)
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Color.miraclesSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Color.miraclesSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.miraclesSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
