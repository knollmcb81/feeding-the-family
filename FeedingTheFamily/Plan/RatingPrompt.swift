import SwiftUI

struct RatingPrompt: View {
    /// Called once the user finishes rating. The optional context is non-empty
    /// when they picked or wrote a "what didn't work?" note (only surfaced for ≤2★).
    let onRate: (Int, String?) -> Void
    @State private var pendingStars: Int? = nil
    @State private var customNote: String = ""
    @FocusState private var noteFocused: Bool

    private static let lowRatingChips: [String] = [
        "Took too long",
        "Kids didn't like it",
        "Didn't taste good",
        "Too many dishes",
        "Made too much",
        "Made too little",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerText)
                .font(AppFont.text(11, weight: .semibold))
                .kerning(0.2)
                .foregroundStyle(T.ink2)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button { tap(star: star) } label: {
                        Text("★")
                            .font(.system(size: 18))
                            .foregroundStyle((pendingStars ?? 0) >= star ? T.accent : T.ink3)
                            .frame(width: 28, height: 28)
                            .scaleEffect((pendingStars ?? 0) >= star ? 1.15 : 1)
                            .animation(.easeInOut(duration: 0.1), value: pendingStars)
                    }
                    .buttonStyle(.plain)
                }
                if pendingStars == nil {
                    Text("tap a star — feeds future drafts")
                        .font(AppFont.text(11))
                        .foregroundStyle(T.ink3)
                        .padding(.leading, 4)
                }
            }

            if let stars = pendingStars, stars <= 2 {
                feedbackEditor(stars: stars)
                    .transition(.opacity.combined(with: .offset(y: -4)))
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

    private var headerText: String {
        if let stars = pendingStars, stars <= 2 {
            return "What didn't work?"
        }
        return "How'd it go?"
    }

    private func tap(star: Int) {
        if star <= 2 {
            // Don't commit yet — show the feedback editor first.
            withAnimation(.easeInOut(duration: 0.18)) {
                pendingStars = star
            }
        } else {
            // 3+ commits immediately, no extra step.
            onRate(star, nil)
        }
    }

    @ViewBuilder
    private func feedbackEditor(stars: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(Self.lowRatingChips, id: \.self) { chip in
                    Button {
                        commit(stars: stars, note: chip)
                    } label: {
                        Text(chip)
                            .font(AppFont.text(11, weight: .semibold))
                            .foregroundStyle(T.ink2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                TextField("or type a note", text: $customNote)
                    .font(AppFont.text(12))
                    .foregroundStyle(T.ink)
                    .tint(T.ink)
                    .focused($noteFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(T.paperDeep)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
                    )
                    .onSubmit {
                        commit(stars: stars, note: customNote)
                    }
                Button {
                    commit(stars: stars, note: customNote.isEmpty ? "" : customNote)
                } label: {
                    Text("Save")
                        .font(AppFont.text(11, weight: .semibold))
                        .foregroundStyle(T.paper)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(T.ink))
                }
                .buttonStyle(.plain)
            }
            Text("Tap a chip or type a note. Skip is fine — the rating still saves.")
                .font(AppFont.text(10))
                .foregroundStyle(T.ink3)
            Button {
                commit(stars: stars, note: "")
            } label: {
                Text("Skip note")
                    .font(AppFont.text(11, weight: .semibold))
                    .foregroundStyle(T.ink3)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    private func commit(stars: Int, note: String) {
        onRate(stars, note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note)
    }
}
