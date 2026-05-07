import SwiftUI
import UIKit

struct ThoughtsView: View {
    @State private var entries: [ThoughtEntry] = []
    @State private var isLoading = true
    @State private var newText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    /// Author identity used for new entries. Falls back to .elisa for safety
    /// (rawValue persisted; see MiraclesPerson). Display uses .displayName.
    private var myPerson: MiraclesPerson {
        AppIdentity.current ?? .elisa
    }

    private var myAuthor: String { myPerson.rawValue }

    var body: some View {
        ZStack {
            Color.miraclesBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader("Thoughts")

                if isLoading {
                    Spacer()
                    ProgressView().tint(Color.miraclesAccent)
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                            .font(.system(size: 32, design: .serif))
                            .foregroundStyle(Color.miraclesSecondary.opacity(0.5))
                        Text("Nothing here")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(Color.miraclesSecondary)
                        Text("Write something, then check it off when done.")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Color.miraclesSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    List {
                        ForEach(entries) { entry in
                            entryRow(entry)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await reload() }
                }

                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Color.miraclesAccent)
                        Text(errorMessage)
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Color.miraclesText)
                        Spacer()
                        Button("Retry") { Task { await reload() } }
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.miraclesAccent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.miraclesAccent.opacity(0.08))
                }

                Divider().background(Color.miraclesText.opacity(0.1))

                // Input area
                HStack(spacing: 10) {
                    Text(myPerson.defaultEmoji)
                        .font(.system(size: 18, design: .serif))

                    TextField("write something...", text: $newText, axis: .vertical)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Color.miraclesText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.miraclesSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.miraclesText.opacity(0.12), lineWidth: 1))
                        .lineLimit(1...4)
                        .focused($inputFocused)

                    Button {
                        Task { await send() }
                    } label: {
                        let isEmpty = newText.trimmingCharacters(in: .whitespaces).isEmpty
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(isEmpty ? Color.miraclesSecondary : .white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(isEmpty ? Color.miraclesText.opacity(0.1) : Color.miraclesAccent)
                        .clipShape(Circle())
                    }
                    .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    // MARK: - Entry row

    private func entryRow(_ entry: ThoughtEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Done button — tap to archive + remove
            Button {
                markDone(entry)
            } label: {
                Circle()
                    .stroke(Color(hex: entry.authorColorHex).opacity(0.7), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.content)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Color.miraclesText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(entry.authorEmoji)
                        .font(.system(size: 10, design: .serif))
                    Text(entry.authorDisplay)
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: entry.authorColorHex))
                    Text("·")
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                    Text(relativeTime(entry.date))
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(Color.miraclesSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.miraclesSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.miraclesText.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Actions

    private func load() async {
        if let disk = NotionService.shared.thoughtsDiskCache(), !disk.isEmpty {
            entries = disk
            isLoading = false
        }
        await reload()
    }

    private func reload() async {
        do {
            entries = try await NotionService.shared.fetchThoughts(force: true)
            errorMessage = nil
        } catch is CancellationError { }
        catch let err as URLError where err.code == .cancelled { }
        catch {
            // Surface the failure so a stalled fetch (network drop, Notion 401)
            // doesn't silently strand Mom on stale or empty data with no signal
            // to retry. Using the existing on-disk cache when available so the
            // UI stays usable while the banner explains the sync issue.
            errorMessage = "Couldn't sync — pull to retry."
        }
        isLoading = false
    }

    private func send() async {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        let originalText = text
        newText = ""
        inputFocused = false
        do {
            try await NotionService.shared.addThought(content: text, author: myAuthor)
            entries = try await NotionService.shared.fetchThoughts(force: true)
            errorMessage = nil
        } catch {
            // Restore the typed text so the user can retry without re-typing,
            // and surface a banner so the silent failure is visible.
            newText = originalText
            errorMessage = "Couldn't post — check connection and tap Send again."
        }
        isSending = false
    }

    private func markDone(_ entry: ThoughtEntry) {
        withAnimation(.easeOut(duration: 0.2)) {
            entries.removeAll { $0.id == entry.id }
        }
        Task { try? await NotionService.shared.archivePage(id: entry.id) }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        switch diff {
        case ..<60:        return "just now"
        case 60..<3600:    return "\(diff / 60)m ago"
        case 3600..<86400: return "\(diff / 3600)h ago"
        default:           return "\(diff / 86400)d ago"
        }
    }
}
