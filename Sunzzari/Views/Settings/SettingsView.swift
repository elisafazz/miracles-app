import SwiftUI

struct SettingsView: View {
    let onComplete: () -> Void

    @State private var selected: MiraclesPerson? = AppIdentity.current

    var body: some View {
        ZStack {
            Color.miraclesBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("My Identity")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .fontDesign(.serif)
                        .foregroundStyle(Color.miraclesText)
                    Text("Who are you?")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                // Identity cards
                VStack(spacing: 16) {
                    identityCard(
                        person: .elisa,
                        emoji: MiraclesPerson.elisa.defaultEmoji,
                        name: MiraclesPerson.elisa.displayName,
                        subtitle: ""
                    )
                    identityCard(
                        person: .mom,
                        emoji: MiraclesPerson.mom.defaultEmoji,
                        name: MiraclesPerson.mom.displayName,
                        subtitle: ""
                    )
                    identityCard(
                        person: .sister,
                        emoji: MiraclesPerson.sister.defaultEmoji,
                        name: MiraclesPerson.sister.displayName,
                        subtitle: ""
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer note
                Text("You can change this anytime in the Settings tab.")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Color.miraclesSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }

    private func identityCard(person: MiraclesPerson, emoji: String, name: String, subtitle: String) -> some View {
        let isSelected = selected == person

        return Button {
            selected = person
            AppIdentity.current = person
            // Re-attempt device token storage now that identity is confirmed
            Task { await StatusService.shared.retryTokenStorage() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onComplete()
            }
        } label: {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 40, design: .serif))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .fontDesign(.serif)
                        .foregroundStyle(Color.miraclesText)
                    Text(subtitle)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, design: .serif))
                        .foregroundStyle(Color.miraclesAccent)
                }
            }
            .padding(18)
            .background(Color.miraclesSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.miraclesAccent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.miraclesAccent.opacity(0.25) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}
