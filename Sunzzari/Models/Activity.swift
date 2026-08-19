import Foundation

struct Activity: Identifiable, Codable {
    let id: String
    var name: String
    var location: String
    var dateSpecific: Bool
    var dateActive: Date?
    var active: Bool
    var seasonal: Bool
    var home: Bool
    var calendarSynced: Bool
    /// Shortlist flag driving the Home "activities to do" list.
    var thinkingAbout: Bool
    var done: Bool
}
