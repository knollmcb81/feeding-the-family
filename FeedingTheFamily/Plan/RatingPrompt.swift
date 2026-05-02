import SwiftUI

struct RatingPrompt: View {
    let onRate: (Int) -> Void
    @State private var hover: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How'd it go?")
                .font(AppFont.text(11, weight: .semibold))
                .kerning(0.2)
                .foregroundStyle(T.ink2)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        onRate(star)
                    } label: {
                        Text("★")
                            .font(.system(size: 18))
                            .foregroundStyle(star <= hover ? T.accent : T.ink3)
                            .frame(width: 28, height: 28)
                            .scaleEffect(star <= hover ? 1.15 : 1)
                            .animation(.easeInOut(duration: 0.1), value: hover)
                    }
                    .buttonStyle(.plain)
                }
                Text("tap a star — feeds future drafts")
                    .font(AppFont.text(11))
                    .foregroundStyle(T.ink3)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(T.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(T.ink3, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        )
    }
}
