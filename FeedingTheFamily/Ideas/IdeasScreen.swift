import SwiftUI

struct IdeasScreen: View {
    @Environment(AppState.self) private var state
    @State private var openInspirationId: UUID? = nil

    private var inspirations: [SnapEntry] {
        state.snapLog
            .filter { $0.savedAsInspiration }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if inspirations.isEmpty {
                emptyState
                    .padding(.horizontal, 22)
                    .padding(.top, 30)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], spacing: 12) {
                        ForEach(inspirations) { entry in
                            Button {
                                openInspirationId = entry.id
                            } label: {
                                inspirationCard(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.paper)
        .sheet(item: Binding(
            get: { inspirations.first(where: { $0.id == openInspirationId }) },
            set: { openInspirationId = $0?.id })
        ) { entry in
            InspirationDetail(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved snaps")
                    .font(AppFont.text(11, weight: .semibold))
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(T.ink3)
                Text("Ideas")
                    .font(AppFont.text(28, weight: .bold))
                    .kerning(-1)
                    .foregroundStyle(T.ink)
            }
            Spacer()
            Text("\(inspirations.count)")
                .font(AppFont.mono(12, weight: .bold))
                .foregroundStyle(T.ink3)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(T.ink3)
            Text("Nothing saved yet")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundStyle(T.ink)
            Text("When you snap a meal you want to remember, tap the bookmark in the result sheet — it'll land here. Tap a saved idea to turn it into a planned recipe.")
                .font(AppFont.text(12.5))
                .foregroundStyle(T.ink3)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private func inspirationCard(_ entry: SnapEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            InspirationGradient(seed: entry.paletteIdx)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(AppFont.text(14, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(T.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("\(entry.kcal) kcal")
                        .font(AppFont.mono(10.5, weight: .semibold))
                        .foregroundStyle(T.ink2)
                    Text("·").foregroundStyle(T.rule)
                    Text("\(entry.protein)g P")
                        .font(AppFont.mono(10.5))
                        .foregroundStyle(T.ink3)
                }
            }
            .padding(.top, 10)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(T.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(T.ruleSoft, lineWidth: 1)
                )
        )
    }
}

/// Stable two-tone gradient placeholder (no real photography in v0).
struct InspirationGradient: View {
    let seed: Int

    private static let palettes: [(Color, Color)] = [
        (Color(hex: 0xf0d4a5), Color(hex: 0xc28a4f)),  // warm amber
        (Color(hex: 0xd9e3c3), Color(hex: 0x6b8a4a)),  // sage
        (Color(hex: 0xf2c4b3), Color(hex: 0xc26947)),  // peach
        (Color(hex: 0xd4d8e5), Color(hex: 0x6a7494)),  // dusk
        (Color(hex: 0xede0c8), Color(hex: 0x9c7a4f)),  // cream
        (Color(hex: 0xc9d8d6), Color(hex: 0x4a6e6a)),  // teal
    ]

    var body: some View {
        let palette = Self.palettes[abs(seed) % Self.palettes.count]
        RadialGradient(
            colors: [palette.0, palette.1],
            center: .topLeading,
            startRadius: 10,
            endRadius: 220
        )
    }
}
