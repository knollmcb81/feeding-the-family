import SwiftUI

/// Manage the side dishes attached to a single day. Sides live on the DayPlan
/// (not on the Meal), so two nights cooking the same recipe can have different
/// pairings. Side ingredients flow into the grocery list when that day is
/// included in the list selection.
struct DaySidesSheet: View {
    let dayLabel: String
    let mealTitle: String
    @Binding var sides: [DaySide]

    @Environment(\.dismiss) private var dismiss
    @State private var addingNew: Bool = false
    @State private var draftName: String = ""
    @State private var draftIngs: [Ingredient] = []
    @State private var ingName: String = ""
    @State private var ingQty: String = ""
    @State private var ingAisle: Aisle = .produce
    @State private var editingIdx: Int? = nil
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(T.rule)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if sides.isEmpty && !addingNew {
                        emptyState
                    }
                    ForEach(Array(sides.enumerated()), id: \.element.id) { idx, side in
                        sideRow(side: side, idx: idx)
                    }
                    if addingNew {
                        addForm
                    } else {
                        addBtn
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
        }
        .background(T.paper)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(dayLabel.uppercased()) · SIDES")
                    .font(AppFont.text(10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink3)
                Text("with \(mealTitle)")
                    .font(AppFont.text(20, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(T.ink)
                    .lineLimit(2)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(T.paperDeep))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(T.ink3)
            Text("No sides yet")
                .font(AppFont.text(14, weight: .semibold))
                .foregroundStyle(T.ink)
            Text("Add a side like bruschetta or salad. Any ingredients you list here will show up in the grocery list when this day is included.")
                .font(AppFont.text(12))
                .foregroundStyle(T.ink2)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private func sideRow(side: DaySide, idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(side.name)
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundStyle(T.ink)
                Spacer()
                Button {
                    sides.remove(at: idx)
                    if editingIdx == idx { editingIdx = nil }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(T.warn)
                        .padding(8)
                        .background(Circle().strokeBorder(T.warn.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(side.name)")
            }
            if !side.ings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(side.ings.enumerated()), id: \.offset) { ingIdx, ing in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(ing.name)
                                .font(AppFont.text(13))
                                .foregroundStyle(T.ink2)
                            Spacer(minLength: 8)
                            Text(ing.qty.isEmpty ? "—" : ing.qty)
                                .font(AppFont.mono(11))
                                .foregroundStyle(T.ink3)
                            Text(ing.aisle.label.lowercased())
                                .font(AppFont.text(10))
                                .foregroundStyle(T.ink3)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(T.paperDeep))
                            Button {
                                sides[idx].ings.remove(at: ingIdx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(T.warn.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Button {
                editingIdx = (editingIdx == idx) ? nil : idx
                ingName = ""
                ingQty = ""
                ingAisle = .produce
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: editingIdx == idx ? "xmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text(editingIdx == idx ? "Done" : "Add ingredient")
                        .font(AppFont.text(11, weight: .semibold))
                }
                .foregroundStyle(T.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(T.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            if editingIdx == idx {
                ingForm { ing in
                    sides[idx].ings.append(ing)
                    ingName = ""
                    ingQty = ""
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
    }

    private var addBtn: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                addingNew = true
                editingIdx = nil
            }
            nameFocused = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add a side")
                    .font(AppFont.text(13, weight: .semibold))
            }
            .foregroundStyle(T.ink2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputField(placeholder: "Side name (e.g. Bruschetta)", text: $draftName)
                .focused($nameFocused)
                .onSubmit { commitNewSide() }

            if !draftIngs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(draftIngs.enumerated()), id: \.offset) { i, ing in
                        HStack(spacing: 8) {
                            Text(ing.name).font(AppFont.text(13)).foregroundStyle(T.ink2)
                            Spacer(minLength: 6)
                            Text(ing.qty.isEmpty ? "—" : ing.qty)
                                .font(AppFont.mono(11))
                                .foregroundStyle(T.ink3)
                            Text(ing.aisle.label.lowercased())
                                .font(AppFont.text(10))
                                .foregroundStyle(T.ink3)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(T.paperDeep))
                            Button {
                                draftIngs.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(T.warn.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ingForm { ing in
                draftIngs.append(ing)
                ingName = ""
                ingQty = ""
            }

            HStack {
                Button {
                    cancelNewSide()
                } label: {
                    Text("Cancel")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(T.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    commitNewSide()
                } label: {
                    Text("Save side")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(canSave ? T.paper : T.ink3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(canSave ? T.ink : T.rule))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commitNewSide() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        sides.append(DaySide(name: trimmed, ings: draftIngs))
        draftName = ""
        draftIngs = []
        ingName = ""
        ingQty = ""
        addingNew = false
    }

    private func cancelNewSide() {
        draftName = ""
        draftIngs = []
        ingName = ""
        ingQty = ""
        addingNew = false
    }

    private func ingForm(onAdd: @escaping (Ingredient) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                inputField(placeholder: "ingredient", text: $ingName)
                inputField(placeholder: "qty", text: $ingQty)
                    .frame(width: 84)
            }
            HStack(spacing: 6) {
                ForEach(Aisle.allCases, id: \.self) { a in
                    Button { ingAisle = a } label: {
                        Text(a.label)
                            .font(AppFont.text(10.5, weight: .semibold))
                            .foregroundStyle(ingAisle == a ? T.paper : T.ink2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(ingAisle == a ? T.ink : Color.clear)
                                    .overlay(
                                        Capsule().strokeBorder(ingAisle == a ? Color.clear : T.rule, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button {
                    let n = ingName.trimmingCharacters(in: .whitespaces).lowercased()
                    guard !n.isEmpty else { return }
                    onAdd(Ingredient(
                        name: n,
                        qty: ingQty.trimmingCharacters(in: .whitespaces),
                        aisle: ingAisle
                    ))
                } label: {
                    Text("+ Ingredient")
                        .font(AppFont.text(11, weight: .semibold))
                        .foregroundStyle(ingName.trimmingCharacters(in: .whitespaces).isEmpty ? T.ink3 : T.accentInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ingName.trimmingCharacters(in: .whitespaces).isEmpty ? T.rule : T.accent))
                }
                .buttonStyle(.plain)
                .disabled(ingName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(AppFont.text(13))
            .foregroundStyle(T.ink)
            .tint(T.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(T.paper)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}
