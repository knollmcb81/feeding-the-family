import SwiftUI

/// 5 lime sparkles fan out + fade. Triggered by giving the view a fresh `.id()`
/// each time you want to play the animation (e.g. when a day's meal changes).
struct SparkleBurst: View {
    @State private var animated = false

    private static let positions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-60, -30, 18),
        (-25,  20, 12),
        ( 18, -28, 16),
        ( 55,  22, 14),
        (  0,   0, 22),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.positions.enumerated()), id: \.offset) { idx, p in
                Image(systemName: "sparkles")
                    .font(.system(size: p.size, weight: .bold))
                    .foregroundStyle(T.accent)
                    .shadow(color: T.accent2.opacity(0.4), radius: 4)
                    .offset(x: p.x, y: p.y)
                    .scaleEffect(animated ? 1.4 : 0.3)
                    .opacity(animated ? 0 : 0.95)
                    .animation(
                        .easeOut(duration: 0.65).delay(Double(idx) * 0.05),
                        value: animated
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animated = true }
    }
}
