import SwiftUI
import UIKit
import CoreLocation

/// 3-person Status: my card on top (interactive), the other 2 stacked below (read-only).
/// Replaces Sunzzari's hummingbird/branch 2-person layout. State persists in the
/// Family Members Notion DB (one row per MiraclesPerson).
struct StatusView: View {

    @State private var entries: [StatusEntry] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var isSaving = false

    // Mine -- locally edited values, flushed to Notion on Save.
    @State private var myMood: Int = 50
    @State private var myAdjective: String = ""
    @State private var customText: String = ""

    static let adjectives: [(label: String, emoji: String)] = [
        ("Happy!",    "😄"),
        ("Grumpy",    "😠"),
        ("Hungry",    "🍕"),
        ("Work Mode", "💼"),
        ("Tired",     "😴"),
        ("Cozy",      "🛋️"),
        ("Excited",   "🤩"),
        ("Loved",     "🥰"),
    ]

    private var myPerson: MiraclesPerson { AppIdentity.current ?? .elisa }
    private var myPageID: String {
        switch myPerson {
        case .elisa:  return Constants.Status.elisaPageID
        case .mom:    return Constants.Status.momPageID
        case .sister: return Constants.Status.sisterPageID
        }
    }
    private var others: [StatusEntry] { entries.filter { $0.person != myPerson } }
    private var mine: StatusEntry? { entries.first { $0.person == myPerson } }

    var body: some View {
        ZStack {
            Color.miraclesBackground.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.miraclesAccent)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.miraclesAccent)
                    Text(error)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        myCard
                        ForEach(others) { otherCard($0) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    // MARK: - My card (interactive)

    private var myCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(myPerson.displayName == "Mom" ? "🌷" : myPerson == .elisa ? "🌸" : "🌼")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(myPerson.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.miraclesText)
                    Text("How are you right now?")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                }
                Spacer()
                Text(moodEmoji(for: myMood))
                    .font(.system(size: 32))
            }

            // Mood slider
            VStack(alignment: .leading, spacing: 6) {
                Text("Mood")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Color.miraclesSecondary)
                HStack(spacing: 10) {
                    Slider(value: Binding(
                        get: { Double(myMood) },
                        set: { myMood = Int($0) }
                    ), in: 0...100, step: 1)
                    .tint(Color(hex: moodColorHex(for: myMood)))
                    Text("\(myMood)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.miraclesText)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            // Adjective chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Feeling")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Color.miraclesSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(Self.adjectives, id: \.label) { adj in
                        Button {
                            myAdjective = adj.label
                            customText = ""
                        } label: {
                            HStack(spacing: 4) {
                                Text(adj.emoji)
                                Text(adj.label)
                                    .font(.system(size: 12, design: .serif))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(myAdjective == adj.label ? Color.miraclesAccent : Color.miraclesBackground)
                            .foregroundStyle(myAdjective == adj.label ? .white : Color.miraclesText)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.miraclesText.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("or type your own…", text: $customText)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Color.miraclesText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.miraclesBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.miraclesText.opacity(0.12), lineWidth: 1))
                    .onChange(of: customText) { _, newValue in
                        if !newValue.isEmpty { myAdjective = newValue }
                    }
            }

            // Save button
            Button {
                Task { await save() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 11)
                .background(Color.miraclesAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSaving)
        }
        .padding(16)
        .background(Color.miraclesSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.miraclesAccent.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Other person card (read-only)

    private func otherCard(_ s: StatusEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(s.personEmoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(s.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.miraclesText)
                    Text(s.moodEmoji)
                        .font(.system(size: 16))
                    Spacer()
                    Text(relativeTime(s.moodUpdatedAt))
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                }
                if !s.adjective.isEmpty {
                    Text(s.adjective)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Color.miraclesText)
                }
                // Slim mood bar (read-only).
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.miraclesText.opacity(0.06))
                        Capsule()
                            .fill(Color(hex: s.moodColorHex))
                            .frame(width: geo.size.width * CGFloat(s.mood) / 100)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(Color.miraclesSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.miraclesText.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Mood helpers

    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 0...20:  return "😴"
        case 21...40: return "😔"
        case 41...60: return "😊"
        case 61...80: return "🌟"
        default:      return "🔥"
        }
    }

    private func moodColorHex(for mood: Int) -> String {
        switch mood {
        case 0...20:  return "#EF4444"
        case 21...40: return "#F97316"
        case 41...60: return "#FBBF24"
        case 61...80: return "#22C55E"
        default:      return "#16A34A"
        }
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let diff = Int(Date().timeIntervalSince(date))
        switch diff {
        case ..<60:        return "just now"
        case 60..<3600:    return "\(diff / 60)m ago"
        case 3600..<86400: return "\(diff / 3600)h ago"
        default:           return "\(diff / 86400)d ago"
        }
    }

    // MARK: - Actions

    private func load() async {
        do {
            let fetched = try await StatusService.shared.fetchAll()
            entries = fetched
            if let me = fetched.first(where: { $0.person == myPerson }) {
                myMood = me.mood
                myAdjective = me.adjective
            }
            isLoading = false
        } catch {
            self.error = "Couldn't load Status. Pull to retry."
            isLoading = false
        }
    }

    private func save() async {
        guard !myPageID.isEmpty else { return }
        isSaving = true
        let adj = customText.isEmpty ? myAdjective : customText
        do {
            try await StatusService.shared.updateMood(myMood, for: myPageID)
            try await StatusService.shared.updateAdjective(adj, for: myPageID)
            customText = ""
            // Refresh from server so others' cards stay current.
            entries = try await StatusService.shared.fetchAll()
        } catch { }
        isSaving = false
    }
}

// MARK: - FlowLayout (chip wrapping)

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rows: [[CGFloat]] = [[]]
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width && currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                rows.append([])
                currentRowWidth = 0
                currentRowHeight = 0
            }
            rows[rows.count - 1].append(size.width)
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
