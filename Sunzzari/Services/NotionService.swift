import Foundation
import os.log

final class NotionService: @unchecked Sendable {
    static let shared = NotionService()
    private let baseURL = "https://api.notion.com/v1"
    private static let logger = Logger(subsystem: "com.elisafazzari.miracles", category: "notion-parser")

    /// Logs when a parser drops rows so integration drift is visible (Fail Loud).
    private func logSkipped(_ kind: String, total: Int, parsed: Int) {
        if parsed < total {
            Self.logger.warning("\(kind) skipped \(total - parsed) of \(total) rows (missing/malformed fields)")
        }
    }

    // MARK: - Memory cache
    private var bestOfCache: (entries: [BestOfEntry], at: Date)?
    private var photosCache: (photos: [FamilyPhoto], at: Date)?
    private var memoriesCache: (memories: [Memory], at: Date)?
    private var restaurantsCache: (items: [Restaurant], at: Date)?
    private var winesCache: (items: [Wine], at: Date)?
    private var activitiesCache: (items: [Activity], at: Date)?
    private var thoughtsCache: (entries: [ThoughtEntry], at: Date)?
    private var coverCache: [String: (url: String?, at: Date)] = [:]
    private var storiesActiveCache: (entries: [StoryPost], at: Date)?
    private var storiesArchiveCache: [Int: (entries: [StoryPost], at: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    private let coverCacheTTL: TimeInterval = 3600 // 1 hour — covers rarely change
    /// Tighter TTL for the active-stories feed so a fresh post shows up quickly
    /// without forcing the user to pull-to-refresh.
    private let storiesActiveTTL: TimeInterval = 60

    func invalidateBestOf() { bestOfCache = nil }
    func invalidatePhotos() { photosCache = nil }
    func invalidateMemories() { memoriesCache = nil }
    func invalidateRestaurants() { restaurantsCache = nil }
    func invalidateWines() { winesCache = nil }
    func invalidateActivities() { activitiesCache = nil }
    func invalidateThoughts() { thoughtsCache = nil }
    func invalidateStories() {
        storiesActiveCache = nil
        storiesArchiveCache.removeAll()
    }

    // MARK: - Disk cache

    private var diskCacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private func saveToDisk(_ data: Data, name: String) {
        let url = diskCacheDir.appendingPathComponent("miracles_\(name).json")
        try? data.write(to: url, options: .atomic)
    }

    private func loadFromDisk(name: String) -> Data? {
        let url = diskCacheDir.appendingPathComponent("miracles_\(name).json")
        return try? Data(contentsOf: url)
    }

    // MARK: - Disk cache accessors (instant warm-start, no network)

    func photosDiskCache() -> [FamilyPhoto]? {
        loadFromDisk(name: "photos").map { parsePhotos(from: $0) }
    }

    func bestOfDiskCache() -> [BestOfEntry]? {
        loadFromDisk(name: "bestof").map { parseBestOf(from: $0) }
    }

    func memoriesDiskCache() -> [Memory]? {
        loadFromDisk(name: "memories").map { parseMemories(from: $0) }
    }

    func restaurantsDiskCache() -> [Restaurant]? {
        loadFromDisk(name: "restaurants").map { parseRestaurants(from: $0) }
    }

    func winesDiskCache() -> [Wine]? {
        loadFromDisk(name: "wines").map { parseWines(from: $0) }
    }

    func activitiesDiskCache() -> [Activity]? {
        loadFromDisk(name: "activities").map { parseActivities(from: $0) }
    }

    func thoughtsDiskCache() -> [ThoughtEntry]? {
        loadFromDisk(name: "thoughts").map { parseThoughts(from: $0) }
    }

    func storiesActiveDiskCache() -> [StoryPost]? {
        loadFromDisk(name: "stories_active").map { parseStoryPosts(from: $0) }
    }

    private var headers: [String: String] {
        // SECURITY: Authorization carries a bearer token. Never log this dictionary or the
        // URLRequest that includes it (no `print(request)`, no `os_log("\(req)")`).
        [
            "Authorization":   "Bearer \(Constants.Notion.token)",
            "Notion-Version":  Constants.Notion.version,
            "Content-Type":    "application/json"
        ]
    }

    // MARK: - Photos

    func fetchPhotos(force: Bool = false) async throws -> [FamilyPhoto] {
        if !force, let cached = photosCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.photos
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.galleryDBID,
                sorts: [["property": "Date Added", "direction": "descending"]]
            )
            let photos = parsePhotos(from: data)
            photosCache = (photos, Date())
            saveToDisk(data, name: "photos")
            return photos
        } catch {
            if let diskData = loadFromDisk(name: "photos") {
                let photos = parsePhotos(from: diskData)
                photosCache = (photos, Date())
                return photos
            }
            throw error
        }
    }

    func createPhoto(_ photo: FamilyPhoto) async throws {
        try await createPage(body: photoPayload(photo))
    }

    func toggleFavorite(pageID: String, isFavorite: Bool) async throws {
        try await updatePage(id: pageID, body: [
            "properties": ["Favorite": ["checkbox": isFavorite]]
        ])
    }

    func updatePhoto(_ photo: FamilyPhoto) async throws {
        try await updatePage(id: photo.id, body: [
            "properties": [
                "Name": titleProp(photo.name),
                "Tags": ["multi_select": photo.tags.map { ["name": $0.rawValue] }]
            ]
        ])
    }

    // MARK: - Memories

    func fetchMemories(force: Bool = false) async throws -> [Memory] {
        if !force, let cached = memoriesCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.memories
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.memoriesDBID,
                sorts: [["property": "Date", "direction": "descending"]]
            )
            let memories = parseMemories(from: data)
            memoriesCache = (memories, Date())
            saveToDisk(data, name: "memories")
            return memories
        } catch {
            if let diskData = loadFromDisk(name: "memories") {
                let memories = parseMemories(from: diskData)
                memoriesCache = (memories, Date())
                return memories
            }
            throw error
        }
    }

    func createMemory(_ memory: Memory) async throws {
        try await createPage(body: memoryPayload(memory))
    }

    func updateMemory(_ memory: Memory) async throws {
        var props: [String: Any] = [
            "Title":    titleProp(memory.title),
            "Date":     dateProp(memory.date),
            "Category": ["select": ["name": memory.category.rawValue]],
            "Notes":    richTextProp(memory.notes)
        ]
        if let url = memory.photoURL { props["Photo URL"] = ["url": url] }
        try await updatePage(id: memory.id, body: ["properties": props])
    }

    // MARK: - Best Of

    func fetchBestOf(force: Bool = false) async throws -> [BestOfEntry] {
        if !force, let cached = bestOfCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.entries
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.bestOfDBID,
                sorts: [["property": "Date", "direction": "descending"]]
            )
            let entries = parseBestOf(from: data)
            bestOfCache = (entries, Date())
            saveToDisk(data, name: "bestof")
            return entries
        } catch {
            if let diskData = loadFromDisk(name: "bestof") {
                let entries = parseBestOf(from: diskData)
                bestOfCache = (entries, Date())
                return entries
            }
            throw error
        }
    }

    func createBestOfEntry(_ entry: BestOfEntry) async throws {
        try await createPage(body: bestOfPayload(entry))
    }

    func updateBestOfEntry(_ entry: BestOfEntry) async throws {
        try await updatePage(id: entry.id, body: [
            "properties": [
                "Entry":    titleProp(entry.entry),
                "Date":     dateProp(entry.date),
                "Category": ["select": ["name": entry.category.rawValue]],
                "Notes":    richTextProp(entry.notes)
            ]
        ])
    }

    func archivePage(id: String) async throws {
        try await updatePage(id: id, body: ["archived": true])
    }

    /// Returns year-only Best Of entries (YYYY-01-01 sentinel),
    /// filtered to Funny Moment and Best Bites — used as the notification fallback pool.
    func fetchUnassignedBestOf() async throws -> [BestOfEntry] {
        let all = try await fetchBestOf()
        return all.filter { $0.isYearOnly && ($0.category == .funnyMoment || $0.category == .bestBites) }
    }

    // MARK: - Database cover images

    /// Fetches the cover image URL for a Notion page or database.
    /// Tries GET /pages, GET /databases, then POST /search as a last resort.
    /// Caches both hits and misses for 1 hour so DBs without covers don't trigger
    /// 3 network round-trips per call.
    func fetchDatabaseCover(id: String) async throws -> String? {
        if let cached = coverCache[id], Date().timeIntervalSince(cached.at) < coverCacheTTL {
            return cached.url
        }

        func extractCover(_ json: [String: Any]) -> String? {
            guard let cover = json["cover"] as? [String: Any] else { return nil }
            if let external = cover["external"] as? [String: Any] {
                return external["url"] as? String
            }
            if let file = cover["file"] as? [String: Any] {
                return file["url"] as? String
            }
            return nil
        }

        func get(_ endpoint: String) async -> (json: [String: Any]?, status: Int) {
            guard let url = URL(string: "\(baseURL)/\(endpoint)") else { return (nil, 0) }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 10
            headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            guard let (data, response) = try? await URLSession.shared.data(for: req),
                  let http = response as? HTTPURLResponse else { return (nil, 0) }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (json, http.statusCode)
        }

        func cacheAndReturn(_ url: String?) -> String? {
            coverCache[id] = (url, Date())
            return url
        }

        // 1. Try pages endpoint (works for regular pages and inline-DB parent pages)
        let pagesResult = await get("pages/\(id)")
        if let json = pagesResult.json, (200...299).contains(pagesResult.status),
           let cover = extractCover(json) { return cacheAndReturn(cover) }

        // 2. Try databases endpoint
        let dbResult = await get("databases/\(id)")
        if let json = dbResult.json, (200...299).contains(dbResult.status),
           let cover = extractCover(json) { return cacheAndReturn(cover) }

        // 3. Search by ID — try pages first (most common for this app's use),
        //    then databases. Using a hardcoded "database" filter here was a bug:
        //    it excluded page objects entirely, which is what the 3 Hub cover IDs are.
        guard let searchURL = URL(string: "\(baseURL)/search") else { return cacheAndReturn(nil) }
        var searchReq = URLRequest(url: searchURL)
        searchReq.httpMethod = "POST"
        searchReq.timeoutInterval = 10
        headers.forEach { searchReq.setValue($1, forHTTPHeaderField: $0) }
        searchReq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "filter": ["value": "page", "property": "object"]
        ])
        if let (data, response) = try? await URLSession.shared.data(for: searchReq),
           let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            let normalizedID = id.replacingOccurrences(of: "-", with: "")
            if let match = results.first(where: {
                ($0["id"] as? String)?.replacingOccurrences(of: "-", with: "") == normalizedID
            }) { return cacheAndReturn(extractCover(match)) }
        }

        return cacheAndReturn(nil)
    }

    // MARK: - Restaurants

    func fetchRestaurants(force: Bool = false) async throws -> [Restaurant] {
        if !force, let cached = restaurantsCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.items
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.restaurantsDBID,
                sorts: [["property": "Name", "direction": "ascending"]]
            )
            let items = parseRestaurants(from: data)
            restaurantsCache = (items, Date())
            saveToDisk(data, name: "restaurants")
            return items
        } catch {
            if let diskData = loadFromDisk(name: "restaurants") {
                let items = parseRestaurants(from: diskData)
                restaurantsCache = (items, Date())
                return items
            }
            throw error
        }
    }

    func createRestaurant(_ r: Restaurant) async throws {
        try await createPage(body: restaurantPayload(r))
    }

    // MARK: - Wines

    func fetchWines(force: Bool = false) async throws -> [Wine] {
        if !force, let cached = winesCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.items
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.winesDBID,
                sorts: [["property": "Wine Name", "direction": "ascending"]]
            )
            let items = parseWines(from: data)
            winesCache = (items, Date())
            saveToDisk(data, name: "wines")
            return items
        } catch {
            if let diskData = loadFromDisk(name: "wines") {
                let items = parseWines(from: diskData)
                winesCache = (items, Date())
                return items
            }
            throw error
        }
    }

    func createWine(_ w: Wine) async throws {
        try await createPage(body: winePayload(w))
    }

    // MARK: - Activities

    func fetchActivities(force: Bool = false) async throws -> [Activity] {
        if !force, let cached = activitiesCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.items
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.activitiesDBID,
                sorts: [["property": "Name", "direction": "ascending"]]
            )
            let items = parseActivities(from: data)
            activitiesCache = (items, Date())
            saveToDisk(data, name: "activities")
            return items
        } catch {
            if let diskData = loadFromDisk(name: "activities") {
                let items = parseActivities(from: diskData)
                activitiesCache = (items, Date())
                return items
            }
            throw error
        }
    }

    func createActivity(_ a: Activity) async throws {
        try await createPage(body: activityPayload(a))
    }

    // MARK: - Private: API

    private func queryDatabase(id: String, sorts: [[String: Any]], filter: [String: Any]? = nil) async throws -> Data {
        var allResults: [[String: Any]] = []
        var startCursor: String? = nil
        // Defense-in-depth: cap accumulator to prevent OOM on runaway DB.
        let maxRows = 10_000

        repeat {
            var body: [String: Any] = ["sorts": sorts, "page_size": 100]
            if let filter { body["filter"] = filter }
            if let cursor = startCursor { body["start_cursor"] = cursor }

            guard let url = URL(string: "\(baseURL)/databases/\(id)/query") else {
                throw NotionError.badURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                // 404 from a database query at our scale is almost always a
                // missing integration grant rather than a deleted DB. Surface
                // the actionable error so the user can fix it in Notion UI.
                if code == 404 {
                    throw NotionError.integrationNotGranted(databaseID: id)
                }
                throw NotionError.httpError(code)
            }

            // Fail loud on mid-pagination parse error rather than returning silent partial data.
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                throw NotionError.parseError
            }
            allResults.append(contentsOf: results)
            if allResults.count > maxRows { throw NotionError.tooManyRows(maxRows) }

            let hasMore = json["has_more"] as? Bool ?? false
            startCursor = hasMore ? json["next_cursor"] as? String : nil
        } while startCursor != nil

        return try JSONSerialization.data(withJSONObject: ["results": allResults])
    }

    // MARK: - Stories

    /// Stories visible in the home carousel: posted in the last 24 hours.
    /// Filter is timestamp-based so we can drop the Archived flag and the cron
    /// (an earlier draft of this feature; collapsed per c-tagteam adversarial review).
    func fetchActiveStories(force: Bool = false) async throws -> [StoryPost] {
        if !force, let cached = storiesActiveCache, Date().timeIntervalSince(cached.at) < storiesActiveTTL {
            return cached.entries
        }
        let cutoff = isoString(forDate: Date().addingTimeInterval(-24 * 60 * 60))
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.storiesDBID,
                sorts: [["property": "Posted At", "direction": "descending"]],
                filter: ["property": "Posted At", "date": ["after": cutoff]]
            )
            let posts = parseStoryPosts(from: data)
            storiesActiveCache = (posts, Date())
            saveToDisk(data, name: "stories_active")
            return posts
        } catch {
            if let diskData = loadFromDisk(name: "stories_active") {
                let posts = parseStoryPosts(from: diskData)
                storiesActiveCache = (posts, Date())
                return posts
            }
            throw error
        }
    }

    /// All stories from a given calendar year. Used by Archive + Year Recap.
    func fetchArchiveStories(year: Int, force: Bool = false) async throws -> [StoryPost] {
        if !force, let cached = storiesArchiveCache[year], Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.entries
        }
        var comps = DateComponents()
        comps.year = year; comps.month = 1; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let yearStart = cal.date(from: comps)!
        var nextYearComps = comps; nextYearComps.year = year + 1
        let yearEnd = cal.date(from: nextYearComps)!
        let filter: [String: Any] = [
            "and": [
                ["property": "Posted At", "date": ["on_or_after": isoString(forDate: yearStart)]],
                ["property": "Posted At", "date": ["before":      isoString(forDate: yearEnd)]]
            ]
        ]
        let data = try await queryDatabase(
            id: Constants.Notion.storiesDBID,
            sorts: [["property": "Posted At", "direction": "descending"]],
            filter: filter
        )
        let posts = parseStoryPosts(from: data)
        storiesArchiveCache[year] = (posts, Date())
        return posts
    }

    @discardableResult
    func createStoryPost(publicID: String, caption: String, person: StoryPost.Person, postedAt: Date, location: String?) async throws -> StoryPost {
        let titleFmt = DateFormatter(); titleFmt.dateFormat = "yyyy-MM-dd HH:mm"
        let title = "\(person.rawValue) — \(titleFmt.string(from: postedAt))"
        var props: [String: Any] = [
            "Name":      titleProp(title),
            "Public ID": richTextProp(publicID),
            "Caption":   richTextProp(caption),
            "Person":    ["select": ["name": person.rawValue]],
            "Posted At": dateTimeProp(postedAt)
        ]
        if let location, !location.isEmpty {
            props["Location"] = richTextProp(location)
        }
        let body: [String: Any] = [
            "parent": ["database_id": Constants.Notion.storiesDBID],
            "properties": props
        ]
        try await createPage(body: body)
        invalidateStories()
        return StoryPost(
            id: UUID().uuidString,
            publicID: publicID,
            caption: caption,
            person: person,
            postedAt: postedAt,
            location: location
        )
    }

    private func parseStoryPosts(from data: Data) -> [StoryPost] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let posts: [StoryPost] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any],
                  let publicID = extractRichText(from: props["Public ID"]),
                  !publicID.isEmpty,
                  let postedAt = extractDate(from: props["Posted At"]),
                  let personRaw = extractSelect(from: props["Person"]),
                  let person = StoryPost.Person(rawValue: personRaw)
            else { return nil }
            return StoryPost(
                id: id,
                publicID: publicID,
                caption: extractRichText(from: props["Caption"]) ?? "",
                person: person,
                postedAt: postedAt,
                location: extractRichText(from: props["Location"])
            )
        }
        logSkipped("stories", total: results.count, parsed: posts.count)
        return posts
    }

    private func createPage(body: [String: Any]) async throws {
        guard let url = URL(string: "\(baseURL)/pages") else { throw NotionError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NotionError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func updatePage(id: String, body: [String: Any]) async throws {
        guard let url = URL(string: "\(baseURL)/pages/\(id)") else { throw NotionError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 10
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NotionError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Private: Parsers

    // Each parser counts skipped rows so silent malformed-row drops surface in logs (Fail Loud).
    private func parsePhotos(from data: Data) -> [FamilyPhoto] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [FamilyPhoto] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any] else { return nil }
            let tagStrings = extractMultiSelect(from: props["Tags"])
            let tags = tagStrings.compactMap { FamilyPhoto.Tag(rawValue: $0) }
            return FamilyPhoto(
                id:            id,
                name:          extractTitle(from: props["Name"]) ?? "Untitled",
                cloudinaryURL: extractURL(from: props["Cloudinary URL"]),
                dateAdded:     extractDate(from: props["Date Added"]),
                isFavorite:    (props["Favorite"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                tags:          tags
            )
        }
        logSkipped("parsePhotos", total: results.count, parsed: parsed.count)
        return parsed
    }

    private func parseMemories(from data: Data) -> [Memory] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [Memory] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any],
                  let date = extractDate(from: props["Date"]) else { return nil }
            let catStr = extractSelect(from: props["Category"]) ?? "Memory"
            return Memory(
                id:       id,
                title:    extractTitle(from: props["Title"]) ?? "Untitled",
                date:     date,
                category: Memory.Category(rawValue: catStr) ?? .memory,
                notes:    extractRichText(from: props["Notes"]) ?? "",
                photoURL: extractURL(from: props["Photo URL"])
            )
        }
        logSkipped("parseMemories", total: results.count, parsed: parsed.count)
        return parsed
    }

    private func parseBestOf(from data: Data) -> [BestOfEntry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [BestOfEntry] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any],
                  let date = extractDate(from: props["Date"]) else { return nil }
            let catStr = extractSelect(from: props["Category"]) ?? "Funny Moment"
            return BestOfEntry(
                id:       id,
                entry:    extractTitle(from: props["Entry"]) ?? "Untitled",
                date:     date,
                category: BestOfEntry.Category(rawValue: catStr) ?? .funnyMoment,
                notes:    extractRichText(from: props["Notes"]) ?? ""
            )
        }
        logSkipped("parseBestOf", total: results.count, parsed: parsed.count)
        return parsed
    }

    // MARK: - Private: Parsers (Hub)

    private func parseRestaurants(from data: Data) -> [Restaurant] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [Restaurant] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any] else { return nil }
            let prefStr = extractSelect(from: props["Preference"])
            return Restaurant(
                id:           id,
                name:         extractTitle(from: props["Name"]) ?? "Untitled",
                beenThere:    (props["Been There?"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                preference:   prefStr.flatMap { Restaurant.Preference(rawValue: $0) },
                location:     extractSelect(from: props["Location"]) ?? "",
                neighborhood: extractRichText(from: props["Neighborhood"]) ?? "",
                goodFor:      extractMultiSelect(from: props["Good For"]),
                topDishes:    extractRichText(from: props["Top Dishes"]) ?? "",
                comments:     extractRichText(from: props["Comments"]) ?? ""
            )
        }
        logSkipped("parseRestaurants", total: results.count, parsed: parsed.count)
        return parsed
    }

    private func parseWines(from data: Data) -> [Wine] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [Wine] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any] else { return nil }
            let typeStr = extractSelect(from: props["Wine Type"]) ?? "Red"
            return Wine(
                id:              id,
                wineName:        extractTitle(from: props["Wine Name"]) ?? "Untitled",
                producer:        extractRichText(from: props["Producer"]) ?? "",
                vintage:         (props["Vintage"] as? [String: Any])?["number"] as? Int,
                region:          extractRichText(from: props["Region"]) ?? "",
                wineType:        Wine.WineType(rawValue: typeStr) ?? .red,
                purchaseLocation: extractSelect(from: props["Purchase Location"]).flatMap { Wine.PurchaseLocation(rawValue: $0) },
                cost:            (props["Cost"] as? [String: Any])?["number"] as? Double,
                rating:          extractSelect(from: props["Rating"]).flatMap { Wine.Rating(rawValue: $0) },
                notes:           extractRichText(from: props["Notes"]) ?? "",
                useForCooking:   (props["Use for Cooking"] as? [String: Any])?["checkbox"] as? Bool ?? false
            )
        }
        logSkipped("parseWines", total: results.count, parsed: parsed.count)
        return parsed
    }

    private func parseActivities(from data: Data) -> [Activity] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let parsed: [Activity] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any] else { return nil }
            return Activity(
                id:             id,
                name:           extractTitle(from: props["Name"]) ?? "Untitled",
                location:       extractRichText(from: props["Location"]) ?? "",
                dateSpecific:   (props["Date-Specific?"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                dateActive:     extractDate(from: props["Date Active"]),
                active:         (props["Active?"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                seasonal:       (props["Seasonal?"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                home:           (props["Home?"] as? [String: Any])?["checkbox"] as? Bool ?? false,
                calendarSynced: (props["Calendar Synced?"] as? [String: Any])?["checkbox"] as? Bool ?? false
            )
        }
        logSkipped("parseActivities", total: results.count, parsed: parsed.count)
        return parsed
    }

    // MARK: - Private: Payload builders

    private func photoPayload(_ photo: FamilyPhoto) -> [String: Any] {
        var props: [String: Any] = [
            "Name":       titleProp(photo.name),
            "Favorite":   ["checkbox": photo.isFavorite],
            "Tags":       ["multi_select": photo.tags.map { ["name": $0.rawValue] }],
            "Date Added": dateProp(photo.dateAdded ?? Date())
        ]
        if let url = photo.cloudinaryURL { props["Cloudinary URL"] = ["url": url] }
        return ["parent": ["database_id": Constants.Notion.galleryDBID], "properties": props]
    }

    private func memoryPayload(_ memory: Memory) -> [String: Any] {
        var props: [String: Any] = [
            "Title":    titleProp(memory.title),
            "Date":     dateProp(memory.date),
            "Category": ["select": ["name": memory.category.rawValue]],
            "Notes":    richTextProp(memory.notes)
        ]
        if let url = memory.photoURL { props["Photo URL"] = ["url": url] }
        return ["parent": ["database_id": Constants.Notion.memoriesDBID], "properties": props]
    }

    private func bestOfPayload(_ entry: BestOfEntry) -> [String: Any] {
        [
            "parent": ["database_id": Constants.Notion.bestOfDBID],
            "properties": [
                "Entry":    titleProp(entry.entry),
                "Date":     dateProp(entry.date),
                "Category": ["select": ["name": entry.category.rawValue]],
                "Notes":    richTextProp(entry.notes)
            ]
        ]
    }

    private func restaurantPayload(_ r: Restaurant) -> [String: Any] {
        var props: [String: Any] = [
            "Name":       titleProp(r.name),
            "Been There?": ["checkbox": r.beenThere],
            "Good For":   ["multi_select": r.goodFor.map { ["name": $0] }],
            "Neighborhood": richTextProp(r.neighborhood),
            "Top Dishes": richTextProp(r.topDishes),
            "Comments":   richTextProp(r.comments)
        ]
        if !r.location.isEmpty { props["Location"] = ["select": ["name": r.location]] }
        if let pref = r.preference { props["Preference"] = ["select": ["name": pref.rawValue]] }
        return ["parent": ["database_id": Constants.Notion.restaurantsDBID], "properties": props]
    }

    private func winePayload(_ w: Wine) -> [String: Any] {
        var props: [String: Any] = [
            "Wine Name":     titleProp(w.wineName),
            "Wine Type":     ["select": ["name": w.wineType.rawValue]],
            "Producer":      richTextProp(w.producer),
            "Region":        richTextProp(w.region),
            "Notes":         richTextProp(w.notes),
            "Use for Cooking": ["checkbox": w.useForCooking]
        ]
        if let vintage = w.vintage { props["Vintage"] = ["number": vintage] }
        if let cost = w.cost { props["Cost"] = ["number": cost] }
        if let loc = w.purchaseLocation { props["Purchase Location"] = ["select": ["name": loc.rawValue]] }
        if let rating = w.rating { props["Rating"] = ["select": ["name": rating.rawValue]] }
        return ["parent": ["database_id": Constants.Notion.winesDBID], "properties": props]
    }

    private func activityPayload(_ a: Activity) -> [String: Any] {
        var props: [String: Any] = [
            "Name":            titleProp(a.name),
            "Location":        richTextProp(a.location),
            "Active?":         ["checkbox": a.active],
            "Seasonal?":       ["checkbox": a.seasonal],
            "Home?":           ["checkbox": a.home],
            "Date-Specific?":  ["checkbox": a.dateSpecific],
            "Calendar Synced?": ["checkbox": a.calendarSynced]
        ]
        if a.dateSpecific, let date = a.dateActive { props["Date Active"] = dateProp(date) }
        return ["parent": ["database_id": Constants.Notion.activitiesDBID], "properties": props]
    }

    // MARK: - Private: Property helpers

    private func titleProp(_ text: String) -> [String: Any] {
        ["title": [["text": ["content": text]]]]
    }

    private func richTextProp(_ text: String) -> [String: Any] {
        ["rich_text": [["text": ["content": text]]]]
    }

    private func dateProp(_ date: Date) -> [String: Any] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        // Pin to UTC so a "today" written at 11:30PM PDT does not round-trip as a different
        // date when read back in another timezone. Notion treats date-only strings as UTC.
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return ["date": ["start": fmt.string(from: date)]]
    }

    /// Datetime-precision Notion date prop. Stories use this so the 24-hour
    /// active-window filter compares timestamps, not date-only strings.
    private func dateTimeProp(_ date: Date) -> [String: Any] {
        ["date": ["start": isoString(forDate: date)]]
    }

    private func isoString(forDate date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    private func extractTitle(from prop: Any?) -> String? {
        guard let arr = (prop as? [String: Any])?["title"] as? [[String: Any]] else { return nil }
        return arr.compactMap { $0["plain_text"] as? String }.joined()
    }

    private func extractRichText(from prop: Any?) -> String? {
        guard let arr = (prop as? [String: Any])?["rich_text"] as? [[String: Any]] else { return nil }
        return arr.compactMap { $0["plain_text"] as? String }.joined()
    }

    private func extractURL(from prop: Any?) -> String? {
        (prop as? [String: Any])?["url"] as? String
    }

    private func extractDate(from prop: Any?) -> Date? {
        guard let dateStr = (prop as? [String: Any]).flatMap({ ($0["date"] as? [String: Any])?["start"] as? String })
        else { return nil }
        // ISO8601DateFormatter with both options handles fractional and non-fractional
        // RFC 3339 timestamps that DateFormatter's strict format strings dropped silently.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateStr) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateStr) { return d }
        // Date-only fallback ("yyyy-MM-dd"). Use device local timezone so calendar
        // component extraction (month, day) in applyEntries/isYearOnly stays consistent.
        let fmtDate = DateFormatter()
        fmtDate.dateFormat = "yyyy-MM-dd"
        return fmtDate.date(from: dateStr)
    }

    private func extractSelect(from prop: Any?) -> String? {
        (prop as? [String: Any]).flatMap { ($0["select"] as? [String: Any])?["name"] as? String }
    }

    private func extractMultiSelect(from prop: Any?) -> [String] {
        guard let items = (prop as? [String: Any])?["multi_select"] as? [[String: Any]] else { return [] }
        return items.compactMap { $0["name"] as? String }
    }

    private func extractFormulaDate(from prop: Any?) -> Date? {
        guard let formula = (prop as? [String: Any])?["formula"] as? [String: Any],
              let dateObj = formula["date"] as? [String: Any],
              let start = dateObj["start"] as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: start) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: start) { return d }
        let fmtDate = DateFormatter()
        fmtDate.dateFormat = "yyyy-MM-dd"
        fmtDate.timeZone = TimeZone(identifier: "UTC")
        fmtDate.locale = Locale(identifier: "en_US_POSIX")
        return fmtDate.date(from: start)
    }

    private func extractFormulaNumber(from prop: Any?) -> Int? {
        guard let formula = (prop as? [String: Any])?["formula"] as? [String: Any] else { return nil }
        if let n = formula["number"] as? Int    { return n }
        if let n = formula["number"] as? Double { return Int(n) }
        return nil
    }

    // MARK: - Thoughts

    func fetchThoughts(force: Bool = false) async throws -> [ThoughtEntry] {
        if !force, let cached = thoughtsCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.entries
        }
        do {
            let data = try await queryDatabase(
                id: Constants.Notion.thoughtsDBID,
                sorts: [["timestamp": "created_time", "direction": "descending"]]
            )
            let entries = parseThoughts(from: data)
            thoughtsCache = (entries, Date())
            saveToDisk(data, name: "thoughts")
            return entries
        } catch {
            if let diskData = loadFromDisk(name: "thoughts") {
                let entries = parseThoughts(from: diskData)
                thoughtsCache = (entries, Date())
                return entries
            }
            throw error
        }
    }

    func addThought(content: String, author: String) async throws {
        try await createPage(body: thoughtPayload(content: content, author: author))
        invalidateThoughts()
    }

    private func thoughtPayload(content: String, author: String) -> [String: Any] {
        [
            "parent": ["database_id": Constants.Notion.thoughtsDBID],
            "properties": [
                "Entry":  titleProp(content),
                "Author": ["select": ["name": author]],
                "Date":   dateProp(Date())
            ]
        ]
    }

    private func parseThoughts(from data: Data) -> [ThoughtEntry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        let fmtFull = DateFormatter(); fmtFull.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let fmtAlt  = DateFormatter(); fmtAlt.dateFormat  = "yyyy-MM-dd'T'HH:mm:ssZ"
        var skipped = 0
        let parsed: [ThoughtEntry] = results.compactMap { page in
            guard let id = page["id"] as? String,
                  let props = page["properties"] as? [String: Any] else {
                skipped += 1; return nil
            }
            let createdStr = page["created_time"] as? String ?? ""
            let date = fmtFull.date(from: createdStr) ?? fmtAlt.date(from: createdStr) ?? Date()
            return ThoughtEntry(
                id:      id,
                content: extractTitle(from: props["Entry"]) ?? "",
                author:  extractSelect(from: props["Author"]) ?? "Elisa",
                date:    date
            )
        }
        logSkipped("parseThoughts", total: results.count, parsed: parsed.count)
        _ = skipped
        return parsed
    }

    enum NotionError: LocalizedError {
        case httpError(Int)
        case badURL
        case parseError
        case tooManyRows(Int)
        /// 404 on a database query is almost always a missing integration grant
        /// rather than a deleted DB at our scale. Carries the DB id so the user
        /// can be told exactly which DB to open in Notion.
        case integrationNotGranted(databaseID: String)
        var errorDescription: String? {
            switch self {
            case .httpError(let code): return "Notion API error: HTTP \(code)"
            case .badURL:              return "Notion API error: malformed URL"
            case .parseError:          return "Notion API error: response parse failed"
            case .tooManyRows(let n):  return "Notion API error: query exceeded \(n) rows"
            case .integrationNotGranted(let id):
                return "Notion integration isn't connected to this database (\(String(id.prefix(8)))). Open the database in Notion → ⋯ → Connections → add the integration."
            }
        }
    }
}
