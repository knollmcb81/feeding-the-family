import SwiftUI

struct EditStaplesSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var addingNew: Bool = false
    @State private var newName: String = ""
    @State private var newQty: String = ""
    @State private var newAisle: Aisle = .produce
    @FocusState private var nameFocused: Bool

    private var staplesByAisle: [(Aisle, [GroceryItem])] {
        Aisle.allCases.compactMap { a in
            let items = state.staples.filter { $0.aisle == a }
            return items.isEmpty ? nil : (a, items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if addingNew {
                        addForm
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    } else {
                        addButton
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                    }

                    ForEach(staplesByAisle, id: \.0) { aisle, items in
                        section(title: aisle.label.uppercased(), items: items)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(T.paper)
            .navigationTitle("Weekly staples")
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

    // ── Add ──────────────────────────────

    private var addButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { addingNew = true }
            nameFocused = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add staple")
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
            HStack(spacing: 8) {
                TextField("e.g. milk", text: $newName)
                    .font(AppFont.text(14))
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(field)
                TextField("qty", text: $newQty)
                    .font(AppFont.text(14))
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(width: 80)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(field)
                    .onSubmit { commit() }
            }
            FlowLayout(spacing: 6) {
                ForEach(Aisle.allCases, id: \.self) { a in
                    Button { newAisle = a } label: {
                        Text(a.label)
                            .font(AppFont.text(11, weight: .semibold))
                            .foregroundStyle(newAisle == a ? T.paper : T.ink2)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(newAisle == a ? T.ink : Color.clear)
                                    .overlay(
                                        Capsule().strokeBorder(newAisle == a ? Color.clear : T.rule, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button {
                    cancelAdd()
                } label: {
                    Text("Cancel")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(T.ink3)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                Button {
                    commit()
                } label: {
                    Text("Add")
                        .font(AppFont.text(12, weight: .semibold))
                        .foregroundStyle(canCommit ? T.paper : T.ink3)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(canCommit ? T.ink : T.rule))
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.ruleSoft, lineWidth: 1))
        )
    }

    private var field: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(T.paper)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.rule, lineWidth: 1))
    }

    private var canCommit: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commit() {
        let name = newName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        let qty = newQty.trimmingCharacters(in: .whitespaces)
        // Avoid dupes by name+aisle.
        if state.staples.contains(where: { $0.name == name && $0.aisle == newAisle }) {
            cancelAdd()
            return
        }
        let item = GroceryItem(
            name: name,
            aisle: newAisle,
            qty: qty.isEmpty ? [] : [qty],
            meals: [],
            source: .staple
        )
        state.staples.append(item)
        newName = ""
        newQty = ""
        nameFocused = true
    }

    private func cancelAdd() {
        newName = ""; newQty = ""
        withAnimation(.easeInOut(duration: 0.2)) { addingNew = false }
    }

    // ── Sections ─────────────────────────

    private func section(title: String, items: [GroceryItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: GroceryItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                state.staples.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(T.warn)
            }
            .buttonStyle(.plain)

            Text(item.name)
                .font(AppFont.text(14))
                .foregroundStyle(T.ink)

            Spacer(minLength: 12)

            // Inline qty editor — tap the qty text to edit it.
            TextField("qty", text: Binding(
                get: { item.qty.joined(separator: " + ") },
                set: { newQty in
                    guard let idx = state.staples.firstIndex(where: { $0.id == item.id }) else { return }
                    let trimmed = newQty.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.staples[idx] = GroceryItem(
                        name: item.name,
                        aisle: item.aisle,
                        qty: trimmed.isEmpty ? [] : [trimmed],
                        meals: item.meals,
                        source: item.source
                    )
                }
            ))
            .font(AppFont.mono(11))
            .foregroundStyle(T.ink2)
            .tint(T.ink)
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .frame(maxWidth: 110)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 22)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T.ruleSoft).frame(height: 1).padding(.horizontal, 22)
        }
    }
}
