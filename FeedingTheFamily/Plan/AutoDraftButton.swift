import SwiftUI

struct AutoDraftButton: View {
    let onTap: () -> Void

    init(_ onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("Auto-draft")
                    .font(AppFont.text(14, weight: .semibold))
                    .kerning(-0.2)
            }
            .foregroundStyle(T.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(T.ink)
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
