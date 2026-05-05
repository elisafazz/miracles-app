import Foundation

struct StoryPost: Identifiable, Codable, Hashable {
    let id: String
    var publicID: String
    var caption: String
    var person: Person
    var postedAt: Date
    var location: String?

    enum Person: String, CaseIterable, Codable {
        case elisa  = "Elisa"
        case mom    = "Mom"
        case sister = "Sister"

        var colorHex: String {
            switch self {
            case .elisa:  return "#F472B6"
            case .mom:    return "#A78BFA"
            case .sister: return "#FB923C"
            }
        }

        var displayName: String {
            switch self {
            case .elisa:  return "DD"
            case .mom:    return "Mom"
            case .sister: return "Beat"
            }
        }
    }

    var thumbnailURL: URL? {
        Self.cloudinaryURL(publicID: publicID, transform: "w_360,c_fill,q_auto,f_auto")
    }

    var fullURL: URL? {
        Self.cloudinaryURL(publicID: publicID, transform: "w_1080,c_fill,q_auto,f_auto")
    }

    private static func cloudinaryURL(publicID: String, transform: String) -> URL? {
        URL(string: "https://res.cloudinary.com/\(Constants.Cloudinary.cloudName)/image/upload/\(transform)/\(publicID)")
    }
}
