# Miracles

Private iOS app for Elisa, her mom, and her sister. Built with SwiftUI, Notion API, and Cloudinary.

---

## Setup (one time)

1. Clone the repo:
   ```bash
   git clone https://github.com/elisafazz/miracles-app.git
   cd miracles-app
   ```
2. Create your local secrets file (gitignored, never committed):
   ```bash
   cp Sunzzari/Config/Secrets.template Sunzzari/Config/Secrets.swift
   ```
   Open `Sunzzari/Config/Secrets.swift` and fill in the real tokens. Ask Elisa if you don't have them.
3. Open `Sunzzari.xcodeproj` in Xcode

---

## Making changes

1. Pull latest before editing:
   ```bash
   git pull origin main
   ```
2. Make changes in Xcode or with Claude Code
3. Build and test (Cmd+R in Xcode)
4. Commit and push:
   ```bash
   git add .
   git commit -m "describe what you changed"
   git push origin main
   ```

After pushing, Xcode Cloud builds automatically (~10-15 min) and delivers to TestFlight.

---

## Project structure

```
Sunzzari/
├── Config/
│   ├── Constants.swift        — Notion DB IDs, ntfy topics, backend endpoints
│   ├── AppColors.swift        — color palette
│   └── AppIdentity.swift      — per-device identity (Elisa / Mom / Sister)
├── Models/                    — data models (FamilyPhoto, Memory, BestOfEntry, etc.)
├── Services/
│   ├── NotionService.swift    — all Notion API calls
│   ├── BoopService.swift      — ntfy-based boop notifications
│   ├── CloudinaryService.swift
│   └── NotificationService.swift
└── Views/
    ├── Today/                 — home tab (boops, memories, nudge)
    ├── Hub/                   — hub tab (restaurants, wine, activities, travel, gallery, on this day)
    ├── Gallery/               — family photo gallery
    ├── OnThisDay/             — memories from this date in past years
    ├── BestOf/                — best of entries by year
    ├── Search/                — universal search
    ├── Travel/                — trips and itineraries
    ├── Settings/              — identity picker (Elisa / Mom / Sister)
    └── Shared/                — reusable components
```

## Stack

- SwiftUI, iOS 17+
- Notion API (direct HTTP, embedded token)
- Cloudinary (unsigned upload, CDN delivery)
- ntfy.sh for boop notifications
- APNs push via miracles-backend (Vercel)
- No auth layer

## Credentials

All in `Sunzzari/Config/Constants.swift` (non-secret) and `Sunzzari/Config/Secrets.swift` (secret, gitignored). The Xcode Cloud build generates `Secrets.swift` automatically from environment variables set in App Store Connect.
