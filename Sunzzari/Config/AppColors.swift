import SwiftUI

// TODO(miracles-phase-3): These hex values + the `sun*` color names are inherited
// from Sunzzari's dark theme. Miracles theme direction is bright + loving (see
// theme-design-notes.md). When Elisa picks a palette from palette-previews/:
//   1. Replace hex values below with the chosen palette
//   2. Rename `sun*` -> `miracles*` (Color.sunBackground -> Color.miraclesBackground)
//      across all call sites (use Find/Replace in Xcode after build clean)
//   3. Update UINavigationBarAppearance + UITabBarAppearance hardcoded #1F2937 in
//      MiraclesApp.swift to match the new surface color
//   4. Switch `.preferredColorScheme(.dark)` in MiraclesApp.swift to `.light`
//      (do this together with the palette change, never alone — see CLAUDE.md
//      "Visual Verification" rule)
//   5. Update accent color in asset catalog (AccentColor.colorset)
//   6. Replace app icon (AppIcon.appiconset) and launch screen
extension Color {
    static let sunBackground = Color(hex: "#030712")
    static let sunAccent     = Color(hex: "#FBBF24")
    static let sunSurface    = Color(hex: "#1F2937")
    static let sunText       = Color(hex: "#FFFFFF")
    static let sunSecondary  = Color.white.opacity(0.4)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
