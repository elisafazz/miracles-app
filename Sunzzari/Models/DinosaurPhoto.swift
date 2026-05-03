import Foundation

struct FamilyPhoto: Identifiable {
    let id: String
    var name: String
    var cloudinaryURL: String?
    var dateAdded: Date?
    var isFavorite: Bool
    var tags: [Tag]

    enum Tag: String, CaseIterable {
        case lovely    = "Lovely"
        case funny     = "Funny"
        case sweet     = "Sweet"
        case cherished = "Cherished"

        var color: String {
            switch self {
            case .lovely:    return "#FFB3C6"
            case .funny:     return "#FFD93D"
            case .sweet:     return "#FF9B7A"
            case .cherished: return "#C77DFF"
            }
        }
    }
}
