# How to Update the Miracles App

Complete reference - from making a code change to all phones receiving the update.

---

## Overview: How Updates Work

```
Edit code -> git push -> Xcode Cloud builds (~10-15 min) -> Archive succeeds
-> All phones get TestFlight notification -> Tap Update
```

Fully automatic. After pushing, Xcode Cloud builds the app and delivers it to TestFlight.

---

## Part 1 - First-Time Setup (once per machine)

**Requirements**: Mac with Xcode and Git.

**1. Clone the repo**
```bash
git clone https://github.com/elisafazz/miracles-app.git
cd miracles-app
```

**2. Create your local secrets file** (required to build - gitignored, never committed)
```bash
cp Sunzzari/Config/Secrets.template Sunzzari/Config/Secrets.swift
```
Open `Sunzzari/Config/Secrets.swift` and replace the placeholder values with the real tokens. Ask Elisa if you don't have them.

**3. Open in Xcode**
```bash
open Sunzzari.xcodeproj
```

---

## Part 2 - Making a Code Change

**1. Pull latest before editing**
```bash
git pull
```

**2. Edit files in Xcode or Claude Code**

Key files:

| File | What it controls |
|------|-----------------|
| `Sunzzari/Config/Secrets.swift` | API tokens - gitignored, NEVER commit |
| `Sunzzari/Config/Constants.swift` | Database IDs and non-secret config |
| `Sunzzari/Config/AppColors.swift` | Color palette |
| `Sunzzari/Config/AppIdentity.swift` | Identity enum (Elisa / Mom / Sister) |
| `Sunzzari/ContentView.swift` | Tab structure |
| `Sunzzari/Views/Today/TodayView.swift` | Today tab (boops, memories, nudge) |
| `Sunzzari/Views/Hub/HubView.swift` | Hub tab |
| `Sunzzari/Views/BestOf/BestOfView.swift` | Best Of tab |
| `Sunzzari/Views/Gallery/GalleryView.swift` | Photo gallery |
| `ci_scripts/ci_post_clone.sh` | Xcode Cloud setup script - do not edit |

**3. Test before pushing**
- Press Cmd+R to build and run in the Simulator or on a device
- The Simulator works for most changes. A physical device is needed for push notifications and camera.

**4. Push to GitHub**
```bash
git add -A
git commit -m "describe what you changed"
git push
```

---

## Part 3 - Monitoring the Build

After pushing, Xcode Cloud starts a build. Monitor at:

**App Store Connect -> Xcode Cloud -> Builds**

Build stages:
1. **Post-Clone** - generates `Secrets.swift` from environment variables
2. **Archive - iOS** - compiles and archives the app (~10-15 min)
3. **TestFlight Internal Testing - iOS** - uploads the archive

**If the progress bar shows ~46% and appears stuck**: this is a display bug. Check the TestFlight tab instead.

---

## Part 4 - Receiving the Update

After Archive - iOS succeeds, all phones (Elisa, Mom, Sister) will receive a TestFlight notification. Tap **Update** in the TestFlight app.

Compliance is handled via `ITSAppUsesNonExemptEncryption` in Info.plist - no manual steps in App Store Connect needed.

---

## Part 5 - Content Changes (no code needed)

Most app content is fetched live from Notion - no code push required:

- **Best Of entries** - edit in the Miracles Best Of Notion database
- **Memories / On This Day** - edit in the Miracles Memories Notion database
- **Photos** - use the Gallery tab in the app (bulk import or one at a time)

---

## Part 6 - Rotating the Notion API Key

If the Notion token needs to be rotated:

1. Go to notion.so/my-integrations -> Miracles integration -> generate a new token
2. Update `Sunzzari/Config/Secrets.swift` locally with the new token
3. Update the `NOTION_TOKEN` environment variable in App Store Connect -> Xcode Cloud -> Manage Workflows -> TestFlight Release -> Environment
4. Push any commit to trigger a new build

---

## Two Repos

| Repo | URL | Purpose | Auto-deploy |
|------|-----|---------|-------------|
| **miracles-app** | github.com/elisafazz/miracles-app | iOS app (all Swift/UI code) | Xcode Cloud -> TestFlight |
| **miracles-backend** | github.com/elisafazz/miracles-backend | Push notification server | Vercel auto-deploy |

99% of changes go in `miracles-app`. The backend is only touched if the push notification server needs changes.

---

## Never Commit Secrets.swift

`Secrets.swift` is gitignored. Never force-add it to git. It is generated automatically during Xcode Cloud builds via `ci_scripts/ci_post_clone.sh` using environment variables stored in App Store Connect.
