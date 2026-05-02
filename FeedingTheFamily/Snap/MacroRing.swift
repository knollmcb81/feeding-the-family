import SwiftUI

/// 3-segment ring (protein/carbs/fat) sized by kcal contribution. Matches the
/// stacked-bar palette used in the This Week card so the same colors mean the
/// same macro everywhere on the Snap tab.
struct MacroRing: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let goalKcal: Int
    var lineWidth: CGFloat = 14

    private var pKcal: Double { protein * 4 }
    private var cKcal: Double { carbs * 4 }
    private var fKcal: Double { fat * 9 }
    private var total: Double { pKcal + cKcal + fKcal }
    private var totalKcal: Int { Int(total.rounded()) }
    private var pctOfGoal: Double {
        goalKcal > 0 ? min(1.5, total / Double(goalKcal)) : 0
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(T.paperDeep, lineWidth: lineWidth)

            if total > 0 {
                segment(start: 0,                         length: pKcal / total, color: T.ink)
                segment(start: pKcal / total,             length: cKcal / total, color: Color(hex: 0xa8a89c))
                segment(start: (pKcal + cKcal) / total,   length: fKcal / total, color: Color(hex: 0xd4d4cc))
            }

            VStack(spacing: 1) {
                Text("\(totalKcal)")
                    .font(AppFont.text(20, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(T.ink)
                Text("\(Int(pctOfGoal * 100))%")
                    .font(AppFont.mono(9.5, weight: .semibold))
                    .foregroundStyle(T.ink3)
            }
        }
    }

    private func segment(start: Double, length: Double, color: Color) -> some View {
        Circle()
            .trim(from: CGFloat(start), to: CGFloat(start + length))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.4), value: total)
    }
}
