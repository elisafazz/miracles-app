import Foundation

enum MiraclesPerson: String {
    case elisa  = "Elisa"
    case mom    = "Mom"
    case sister = "Sister"

    /// User-facing nickname. rawValue stays stable so UserDefaults persistence
    /// and Notion sender-name strings (e.g., existing BestOf entries) keep
    /// decoding correctly across nickname changes.
    var displayName: String {
        switch self {
        case .elisa:  return "DD"
        case .mom:    return "Mom"
        case .sister: return "Beat"
        }
    }
}

struct AppIdentity {
    static let udKey = "miracles_identity"

    static var current: MiraclesPerson? {
        get { UserDefaults.standard.string(forKey: udKey).flatMap(MiraclesPerson.init) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: udKey) }
    }

    static var isElisa: Bool  { current == .elisa }
    static var isMom: Bool    { current == .mom }
    static var isSister: Bool { current == .sister }
}
