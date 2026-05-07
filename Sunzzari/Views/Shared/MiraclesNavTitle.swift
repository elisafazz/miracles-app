import SwiftUI

// iOS 26.3 ignores UINavigationBarAppearance, so the system .navigationTitle
// renders titles white on cream and they vanish. Use this in place of
// .navigationTitle("X") + .navigationBarTitleDisplayMode(.inline) to render
// the inline title via a principal toolbar item with explicit color/font.
// Keeps the navigationTitle for back-button label and VoiceOver.
extension View {
    func miraclesInlineTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.miraclesText)
                }
            }
    }
}
