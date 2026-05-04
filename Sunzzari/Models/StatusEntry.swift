import Foundation
import CoreLocation

struct StatusEntry: Identifiable {
    let id: String              // Notion page ID (Family Members row)
    let name: String            // MiraclesPerson rawValue: "Elisa", "Mom", "Sister"
    let mood: Int               // 0-100
    let adjective: String       // e.g. "Happy!", "Tired"
    let moodUpdatedAt: Date?
    let latitude: Double?
    let longitude: Double?
    let locationUpdatedAt: Date?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var person: MiraclesPerson? { MiraclesPerson(rawValue: name) }

    var displayName: String { person?.displayName ?? name }

    var personEmoji: String {
        switch person {
        case .elisa:  return "🌸"
        case .mom:    return "🌷"
        case .sister: return "🌼"
        case .none:   return "💛"
        }
    }

    /// Per-person accent (matches ThoughtEntry).
    var accentColorHex: String {
        switch person {
        case .elisa:  return "#D4815B"
        case .mom:    return "#8FA67E"
        case .sister: return "#F5C76A"
        case .none:   return "#2A2421"
        }
    }

    var moodEmoji: String {
        switch mood {
        case 0...20:  return "😴"
        case 21...40: return "😔"
        case 41...60: return "😊"
        case 61...80: return "🌟"
        default:      return "🔥"
        }
    }

    var moodColorHex: String {
        switch mood {
        case 0...20:  return "#EF4444"
        case 21...40: return "#F97316"
        case 41...60: return "#FBBF24"
        case 61...80: return "#22C55E"
        default:      return "#16A34A"
        }
    }
}
