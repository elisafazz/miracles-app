import Foundation

// MIRACLES Phase 2 wired -- Notion DBs and Family Member pages live under
// 🏠 Personal Hub > Family > Lovies Dashboard (created 2026-05-03).
// IDs are Notion database IDs (not data source IDs); the iOS code path uses
// /v1/databases/{id}/query and parent.database_id, both of which accept the
// database ID. See ~/Dropbox/claude/miracles/notion-db-scaffold.md.
//
// REQUIRED ONE-TIME UI STEP (Elisa): the iOS app's Notion integration must be
// granted access to each new DB and to each family member page. Open each DB
// and each page in Notion, click ... > Connections > Add the integration.
// Without this, /v1/databases/{id}/query and PATCH /v1/pages/{id} return 404.
//
// Cloudinary cloud name + upload preset MUST be replaced once Miracles Cloudinary
// is configured.
// Boop and Status ntfy topics are fresh per-Miracles strings (not shared with Sunzzari).
// Push endpoint targets miracles-backend (not yet created -- see backend-strategy.md).

enum Constants {

    enum Notion {
        static let token        = Secrets.Notion.token
        static let galleryDBID      = "c7f3c7dd-d7aa-456f-b85f-dfaf6897425a"
        static let memoriesDBID     = "bf1df87c-fb26-4715-ab25-67f9976fe897"
        static let bestOfDBID       = "3f222362-faa6-4e4d-b0a5-61e0b4a45942"
        static let restaurantsDBID  = "692d29ef-a779-4460-8ed0-3b4726088a5e"
        static let winesDBID        = "eb3b0f92-ab79-4e24-933c-53f0c9632e42"
        static let activitiesDBID   = "d80d2557-c2f4-4aef-a97b-ec1287e59051"
        static let familyDBID       = "a6973030-4de0-49b5-99e0-ba73cb1bc056"
        static let version          = "2022-06-28"
    }

    enum Cloudinary {
        // TODO Phase 2: replace with Miracles Cloudinary cloud + upload preset
        static let cloudName    = "MIRACLES_PLACEHOLDER_cloudName"
        static let uploadPreset = "miracles_uploads"
    }

    enum Travel {
        static let tripsDBID = "795bf754-b15d-4682-a911-2f00e1b0b5a2"
        static let itemsDBID = "1d3e29e0-8079-4dfe-aa13-b41f02010a84"
        // Trip Legs DB intentionally not created for Miracles v1: iOS code never
        // queries this ID. Kept as a placeholder to preserve the Travel enum shape.
        static let legsDBID  = "00000000-0000-0000-0000-000000000000"
    }

    enum Boop {
        /// Private shared topic for Miracles -- distinct from Sunzzari.
        /// All three Miracles users (Elisa, Mom, Sister) subscribe to this.
        static let topic = "miracles-boop-3a8f2d17e9c4"
    }

    enum Anthropic {
        static let model = "claude-sonnet-4-6"
    }

    enum Status {
        // The Status enum holds the per-person Notion page IDs used by
        // StatusService for APNs token storage, location updates, and the
        // shared TodayPick anchor. These are pages in the Family Members DB
        // (familyDBID above), one row per MiraclesPerson.
        static let ntfyTopic = "miracles-status-c5e1b94f7a28"
        static let elisaPageID  = "356f3cdd-67a4-81f6-a71c-c3bcc789c8fb"
        static let momPageID    = "356f3cdd-67a4-8162-85ac-f787bcc44f84"
        static let sisterPageID = "356f3cdd-67a4-81bf-a617-e4a0faaa1902"
        /// APNs push backend
        static let pushEndpoint    = "https://miracles-backend.vercel.app/api/push"
        // TODO(miracles-phase-5): update to miracles-backend once backend is created
        static let analyzeEndpoint = "https://miracles-backend.vercel.app/api/analyze"
        static let pushSecret      = Secrets.Push.secret
    }
}
