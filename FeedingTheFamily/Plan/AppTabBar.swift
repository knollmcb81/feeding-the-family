import SwiftUI

struct AppTabBar: View {
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                tabButton(item)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            T.paper
                .overlay(alignment: .top) {
                    Rectangle().fill(T.rule).frame(height: 1)
                }
        )
    }

    @ViewBuilder
    private func tabButton(_ item: AppTab) -> some View {
        let active = tab == item
        Button { tab = item } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .top) {
                    if active {
                        Capsule()
                            .fill(T.accent)
                            .frame(width: 22, height: 3)
                            .offset(y: -10)
                    }
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(active ? T.ink : T.ink3)
                }
                .frame(height: 22)
                Text(item.label)
                    .font(AppFont.text(10.5, weight: .semibold))
                    .kerning(0.1)
                    .foregroundStyle(active ? T.ink : T.ink3)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}
