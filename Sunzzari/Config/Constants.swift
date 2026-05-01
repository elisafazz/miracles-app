import Foundation

// MIRACLES PHASE 1 -- placeholder constants.
// All "00000000-0000-0000-0000-000000000000" Notion IDs MUST be replaced in Phase 2
// per ~/Dropbox/claude/miracles/notion-db-scaffold.md once Elisa creates the Miracles
// workspace + databases.
// Cloudinary cloud name + upload preset MUST be replaced once Miracles Cloudinary is
// configured.
// Boop and Status ntfy topics are fresh per-Miracles strings (not shared with Sunzzari).
// Push endpoint targets miracles-backend (not yet created -- see backend-strategy.md).

enum Constants {

    enum Notion {
        static let token        = Secrets.Notion.token
        // TODO Phase 2: replace with Miracles Notion DB IDs from notion-db-scaffold.md
        static let dinosaursDBID = "00000000-0000-0000-0000-000000000000"
        static let memoriesDBID  = "00000000-0000-0000-0000-000000000000"
        static let bestOfDBID       = "00000000-0000-0000-0000-000000000000"
        static let restaurantsDBID  = "00000000-0000-0000-0000-000000000000"
        static let winesDBID        = "00000000-0000-0000-0000-000000000000"
        static let activitiesDBID   = "00000000-0000-0000-0000-000000000000"
        // Cathy-specific feature DBs -- kept as placeholders to preserve compile state
        // for restored dead code (NotionService methods). Phase 1.5 surgical removal will
        // strip these and the methods that reference them.
        static let cycleTrackerDBID = "00000000-0000-0000-0000-000000000000"
        static let creditsTrackerDBID = "00000000-0000-0000-0000-000000000000"
        static let thoughtActionDBID  = "00000000-0000-0000-0000-000000000000"
        static let miraclesInfoDBID   = "00000000-0000-0000-0000-000000000000"
        static let version          = "2022-06-28"
    }

    enum Cloudinary {
        // TODO Phase 2: replace with Miracles Cloudinary cloud + upload preset
        static let cloudName    = "MIRACLES_PLACEHOLDER_cloudName"
        static let uploadPreset = "miracles_uploads"
    }

    enum Travel {
        // TODO Phase 2: replace with Miracles Travel DB IDs from notion-db-scaffold.md
        static let tripsDBID = "00000000-0000-0000-0000-000000000000"
        static let itemsDBID = "00000000-0000-0000-0000-000000000000"
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
        // Cards/Status feature is OUT for Miracles v1, but the StatusService class
        // is RETAINED because it provides general push/location/token infrastructure
        // used by Boop, Today, Best Of, Settings. The Status enum constants below are
        // placeholders preserving compile state until Phase 1.5 / Phase 6 surgical work.
        static let ntfyTopic = "miracles-status-c5e1b94f7a28"
        // TODO Phase 6: replace partner-pair page IDs with MiraclesPerson page IDs
        // (Elisa / Mom / Sister, three pages) once Cards is decided IN/OUT
        static let elisaPageID  = "00000000-0000-0000-0000-000000000000"
        static let momPageID    = "00000000-0000-0000-0000-000000000000"
        static let sisterPageID = "00000000-0000-0000-0000-000000000000"
        /// APNs push backend
        static let pushEndpoint = "https://miracles-backend.vercel.app/api/push"
        static let pushSecret   = Secrets.Push.secret
    }
}
