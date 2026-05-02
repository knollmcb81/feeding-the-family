import SwiftUI

struct HistorySheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var sortedWeeks: [ArchivedWeek] {
        state.archivedWeeks.sorted { $0.mondayDate > $1.mondayDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedWeeks.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(sortedWeeks) { week in
                                weekCard(week)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(T.paper)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.text(14, weight: .semibold))
                        .foregroundStyle(T.ink)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(T.ink3)
            Text("No archived weeks yet")
                .font(AppFont.text(15, weight: .semibold))
                .foregroundStyle(T.ink)
            Text("Past weeks land here automatically every Monday.")
                .font(AppFont.text(12))
                .foregroundStyle(T.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func weekCard(_ week: ArchivedWeek) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(week.headline)
                    .font(AppFont.text(15, weight: .bold))
                    .kerning(-0.3)
                    .foregroundStyle(T.ink)
                Spacer()
                Text(week.label)
                    .font(AppFont.mono(10.5))
                    .foregroundStyle(T.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(week.week.enumerated()), id: \.offset) { idx, day in
                    HStack(spacing: 10) {
                        Text(day.day)
                            .font(AppFont.text(12, weight: .bold))
                            .foregroundStyle(T.ink2)
                            .frame(width: 34, alignment: .leading)
                        Text(day.date)
                            .font(AppFont.mono(10))
                            .foregroundStyle(T.ink3)
                            .frame(width: 50, alignment: .leading)
                        let m = Planner.activeMeal(id: day.mealId, overrides: state.mealOverrides, custom: state.customMeals)
                        Text(m.title)
                            .font(AppFont.text(13))
                            .foregroundStyle(T.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .overlay(alignment: .bottom) {
                        if idx < week.week.count - 1 {
                            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 14)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
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
