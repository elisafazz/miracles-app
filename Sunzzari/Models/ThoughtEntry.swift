import Foundation

struct ThoughtEntry: Identifiable {
    let id: String
    let content: String
    let author: String   // MiraclesPerson.rawValue: "Elisa", "Mom", or "Sister"
    let date: Date       // parsed from Notion created_time

    /// Resolve to a MiraclesPerson when the author string matches a known case.
    var person: MiraclesPerson? { MiraclesPerson(rawValue: author) }

    /// Display nickname ("DD" / "Mom" / "Beat"). Falls back to the raw author
    /// string for any legacy entries that don't decode cleanly.
    var authorDisplay: String { person?.displayName ?? author }

    var authorEmoji: String { person?.defaultEmoji ?? "💬" }

    var authorColorHex: String {
        switch person {
        case .elisa:  return "#D4815B" // terracotta
        case .mom:    return "#8FA67E" // sage
        case .sister: return "#F5C76A" // soft yellow
        case .none:   return "#2A2421"
        }
    }
}
