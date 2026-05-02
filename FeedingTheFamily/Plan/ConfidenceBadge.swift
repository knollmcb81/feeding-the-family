import SwiftUI

struct ConfidenceBadge: View {
    let confidence: Double
    let trend: Trend

    private var color: Color {
        if confidence >= 4.2 { return T.accent2 }
        if confidence > 0 && confidence < 3 { return T.warn }
        return T.ink3
    }

    private var arrow: String {
        switch trend {
        case .up:   return "↗"
        case .down: return "↘"
        case .flat: return "→"
        case .new:  return "·"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(String(format: "%.1f★", confidence))
            Text(arrow).opacity(0.7)
        }
        .font(AppFont.mono(9.5, weight: .bold))
        .kerning(0.3)
        .foregroundStyle(color)
    }
}
