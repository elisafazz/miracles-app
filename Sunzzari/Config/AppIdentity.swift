import Foundation

enum MiraclesPerson: String {
    case elisa  = "Elisa"
    case mom    = "Mom"
    case sister = "Sister"
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
