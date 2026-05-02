import SwiftUI

struct AnalyzingView: View {
    let onDone: () -> Void
    @State private var step: Int = 0

    private let steps = [
        "detecting items",
        "estimating portions",
        "looking up nutrition",
    ]

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(T.accent)
                .symbolEffect(.pulse, options: .repeating)
            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, text in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(T.rule, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                            if idx < step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(T.accent2)
                            } else if idx == step {
                                Circle()
                                    .fill(T.accent)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(idx == step ? 1 : 0.5)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: step)
                            }
                        }
                        Text(text)
                            .font(AppFont.text(13, weight: .semibold))
                            .foregroundStyle(idx <= step ? T.ink : T.ink3)
                            .strikethrough(idx < step, color: T.ink3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 60)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
        .onAppear { runSteps() }
    }

    private func runSteps() {
        // 3 steps × ~400ms each, then done.
        for i in 1...steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = i
                }
                if i == steps.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDone()
                    }
                }
            }
        }
    }
}
