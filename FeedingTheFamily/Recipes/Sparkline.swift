import SwiftUI

/// Tiny rating-history polyline. Renders as a smoothed line with end dot.
/// Shows nothing for ≤1 ratings (single-point lines aren't useful at this size).
struct Sparkline: View {
    let history: [Int]
    var width: CGFloat = 56
    var height: CGFloat = 18

    private var color: Color {
        guard let last = history.last else { return T.ink3 }
        if last >= 4 { return T.accent2 }
        if last <= 2 { return T.warn }
        return T.ink3
    }

    var body: some View {
        GeometryReader { geo in
            if history.count >= 2 {
                let w = geo.size.width
                let h = geo.size.height
                let xs = stride(from: 0.0, to: 1.0 + 0.0001, by: 1.0 / Double(history.count - 1))
                    .prefix(history.count)
                let pts: [CGPoint] = zip(xs, history).map { x, v in
                    let y = 1.0 - (Double(v - 1) / 4.0)  // map 1...5 → 1...0
                    return CGPoint(x: x * w, y: y * h)
                }

                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() {
                        p.addLine(to: pt)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let endPt = pts.last {
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(endPt)
                }
            }
        }
        .frame(width: width, height: height)
    }
}
