import SwiftUI

// Direction 1 -- Warm Earth + Cream (locked 2026-05-04 by Elisa).
// "Bright + loving + not religious." Italian-villa, family-album warmth.
// See ~/Dropbox/claude/miracles/theme-design-notes.md for direction rationale
// and palette-previews/direction-1-warm-earth.png for the reference mockup.
extension Color {
    static let miraclesBackground = Color(hex: "#FBF6E9") // warm cream -- page background
    static let miraclesAccent     = Color(hex: "#D4815B") // terracotta -- primary accent
    static let miraclesSurface    = Color(hex: "#FFFFFF") // white -- cards, nav bar, tab bar
    static let miraclesText       = Color(hex: "#2A2421") // deep charcoal -- primary text
    static let miraclesSecondary  = Color(hex: "#2A2421").opacity(0.5) // muted charcoal -- secondary text
    static let miraclesSage       = Color(hex: "#8FA67E") // sage -- secondary accent
    static let miraclesYellow     = Color(hex: "#F5C76A") // soft yellow -- tertiary highlights / ratings

    // Charcoal-on-cream divider / hairline tokens. Replace `Color.white.opacity(x)`
    // call sites that sit on the cream/white surfaces with these so the strokes
    // are actually visible on the light theme. (StoryPlayerView's progress bar
    // and other dark-on-photo overlays still use Color.white.opacity directly.)
    static let miraclesDivider    = Color(hex: "#2A2421").opacity(0.10) // hairline rule / faint stroke
    static let miraclesChipFill   = Color(hex: "#2A2421").opacity(0.06) // chip / capsule fill
    static let miraclesChipStroke = Color(hex: "#2A2421").opacity(0.15) // chip / capsule stroke

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
