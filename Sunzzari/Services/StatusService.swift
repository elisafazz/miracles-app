import Foundation
import CoreLocation

/// Infra service kept after the Status tab was replaced by Stories.
/// Handles APNs token storage, push fan-out via Vercel backend, location ping,
/// and the shared Tier-3 Today pick — all still load-bearing for other features
/// (boops, AddEntryView pushes, daily setup, location updates).
final class StatusService: @unchecked Sendable {
    static let shared = StatusService()
    private init() {}

    private let notionBase = "https://api.notion.com/v1"
    private let pendingTokenKey = "miracles_pending_apns_token"

    /// Stable anchor page for shared state (Today pick). Elisa is the primary
    /// user and owns this page; Mom and Sister read/write it for the shared
    /// daily pick coordination.
    private var sharedAnchorPageID: String { Constants.Status.elisaPageID }

    private var notionHeaders: [String: String] {
        [
            "Authorization":  "Bearer \(Constants.Notion.token)",
            "Notion-Version": Constants.Notion.version,
            "Content-Type":   "application/json"
        ]
    }

    // MARK: - Identity routing

    private func pageID(for person: MiraclesPerson) -> String {
        switch person {
        case .elisa:  return Constants.Status.elisaPageID
        case .mom:    return Constants.Status.momPageID
        case .sister: return Constants.Status.sisterPageID
        }
    }

    /// Page IDs for the other 2 family members (used for push fan-out).
    /// Skips empty IDs so a not-yet-configured page does not get a request.
    private func otherPageIDs(for person: MiraclesPerson) -> [String] {
        let all: [MiraclesPerson] = [.elisa, .mom, .sister]
        return all.filter { $0 != person }.map(pageID(for:)).filter { !$0.isEmpty }
    }

    // MARK: - Update location

    func updateLocation(_ coord: CLLocationCoordinate2D, for pageID: String) async throws {
        let isoNow = isoString(for: Date())
        try await patchPage(id: pageID, body: [
            "properties": [
                "Latitude":          ["number": coord.latitude],
                "Longitude":         ["number": coord.longitude],
                "LocationUpdatedAt": ["date": ["start": isoNow]]
            ]
        ])
    }

    // MARK: - APNs push (via Vercel backend)

    /// Store this device's APNs token in its own Notion Status page.
    /// Always caches the token in UserDefaults first. If identity is not yet set
    /// (first-launch race condition), the Notion write is deferred — call
    /// retryTokenStorage() after identity is confirmed in SettingsView.
    func storeDeviceToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: pendingTokenKey)
        guard let me = AppIdentity.current else { return }
        let ownPageID = pageID(for: me)
        guard !ownPageID.isEmpty else { return }
        try? await patchPage(id: ownPageID, body: [
            "properties": [
                "DeviceToken": ["rich_text": [["text": ["content": token]]]]
            ]
        ])
    }

    /// Re-attempt token storage after identity is confirmed.
    /// Call this from SettingsView when the user selects their identity.
    func retryTokenStorage() async {
        guard let me = AppIdentity.current else { return }
        guard let token = UserDefaults.standard.string(forKey: pendingTokenKey),
              !token.isEmpty else { return }
        let ownPageID = pageID(for: me)
        guard !ownPageID.isEmpty else { return }
        try? await patchPage(id: ownPageID, body: [
            "properties": [
                "DeviceToken": ["rich_text": [["text": ["content": token]]]]
            ]
        ])
    }

    /// Send an APNs push to the other 2 family members' devices via the Vercel backend.
    /// Fetches each recipient's DeviceToken from Notion, then POSTs to the push endpoint.
    /// Sends are run in parallel; failures on one recipient do not block the other.
    func sendPush(title: String, body: String) async {
        guard let me = AppIdentity.current else { return }
        let recipients = otherPageIDs(for: me)
        guard !recipients.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for pageID in recipients {
                group.addTask { [weak self] in
                    await self?.sendPushTo(pageID: pageID, title: title, body: body)
                }
            }
        }
    }

    private func sendPushTo(pageID: String, title: String, body: String) async {
        guard let token = await fetchDeviceToken(pageID: pageID), !token.isEmpty else { return }
        guard let url = URL(string: Constants.Status.pushEndpoint) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // TODO(miracles-phase-5): miracles-backend may rename this header to X-Miracles-Secret. Coordinate with backend repo before deploy.
        req.setValue(Constants.Status.pushSecret, forHTTPHeaderField: "X-Sunzzari-Secret")
        let payload: [String: String] = ["title": title, "body": body, "deviceToken": token]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
    }

    private func fetchDeviceToken(pageID: String) async -> String? {
        guard let url = URL(string: "\(notionBase)/pages/\(pageID)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        notionHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["properties"] as? [String: Any],
              let rtArr = (props["DeviceToken"] as? [String: Any])?["rich_text"] as? [[String: Any]]
        else { return nil }
        return rtArr.compactMap { $0["plain_text"] as? String }.joined().nilIfEmpty
    }

    // MARK: - Shared Today pick (Today tab unification)

    /// Reads the shared Tier-3 pick from the family anchor page (Elisa's).
    /// Format stored in TodayPick property: "YYYY-MM-DD:entryID"
    /// Returns the entryID only if the stored date matches today's dateStr.
    func fetchTodayPick(for dateStr: String) async -> String? {
        guard !sharedAnchorPageID.isEmpty,
              let url = URL(string: "\(notionBase)/pages/\(sharedAnchorPageID)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        notionHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["properties"] as? [String: Any],
              let rtArr = (props["TodayPick"] as? [String: Any])?["rich_text"] as? [[String: Any]]
        else { return nil }
        let value = rtArr.compactMap { $0["plain_text"] as? String }.joined()
        let parts = value.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, String(parts[0]) == dateStr else { return nil }
        return String(parts[1])
    }

    /// Writes the shared Tier-3 pick to the family anchor page (Elisa's).
    func storeTodayPick(dateStr: String, entryID: String) async {
        guard !sharedAnchorPageID.isEmpty else { return }
        let value = "\(dateStr):\(entryID)"
        try? await patchPage(id: sharedAnchorPageID, body: [
            "properties": [
                "TodayPick": ["rich_text": [["text": ["content": value]]]]
            ]
        ])
    }

    // MARK: - Helpers

    private func patchPage(id: String, body: [String: Any]) async throws {
        guard let url = URL(string: "\(notionBase)/pages/\(id)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        notionHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private func isoString(for date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
