import SwiftUI

// MARK: - Shimmer modifier

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -0.3

    func body(content: Content) -> some View {
        content
            .overlay(shimmer)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }

    private var shimmer: some View {
        LinearGradient(
            stops: [
                .init(color: .clear,                   location: phase - 0.3),
                .init(color: .white.opacity(0.08),     location: phase),
                .init(color: .clear,                   location: phase + 0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

extension View {
    func miraclesShimmer() -> some View { modifier(ShimmerEffect()) }
}

// MARK: - Skeleton entry card (matches BestOfEntryCard shape)

struct SkeletonEntryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                block(width: 72, height: 12)
                Spacer()
                block(width: 44, height: 10)
            }
            block(height: 16)
            block(width: 180, height: 12)
        }
        .padding(16)
        .background(Color.miraclesSurface.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .miraclesShimmer()
    }

    private func block(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.miraclesSurface)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: height)
    }
}
