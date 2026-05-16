import Foundation

struct StoryPost: Identifiable, Codable, Hashable {
    let id: String
    var publicID: String
    var caption: String
    var person: Person
    var postedAt: Date
    var location: String?
    var reactions: [Reaction]

    struct Reaction: Identifiable, Codable, Hashable {
        let person: Person
        let emoji: String
        var id: String { person.rawValue }
    }

    init(id: String, publicID: String, caption: String, person: Person,
         postedAt: Date, location: String?, reactions: [Reaction] = []) {
        self.id = id; self.publicID = publicID; self.caption = caption
        self.person = person; self.postedAt = postedAt; self.location = location
        self.reactions = reactions
    }

    private enum CodingKeys: String, CodingKey {
        case id, publicID, caption, person, postedAt, location, reactions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self,  forKey: .id)
        publicID = try c.decode(String.self,  forKey: .publicID)
        caption  = try c.decode(String.self,  forKey: .caption)
        person   = try c.decode(Person.self,  forKey: .person)
        postedAt = try c.decode(Date.self,    forKey: .postedAt)
        location = try c.decodeIfPresent(String.self,  forKey: .location)
        reactions = (try? c.decodeIfPresent([Reaction].self, forKey: .reactions)) ?? []
    }

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
