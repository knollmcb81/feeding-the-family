import SwiftUI

struct ImportRecipeSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// Set after a successful import — parent uses it to open RecipeDetail.
    @Binding var importedMealId: String?

    @State private var url: String = ""
    @State private var importing: Bool = false
    @State private var errorMsg: String? = nil
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    urlField
                    if let msg = errorMsg {
                        errorBanner(msg)
                    }
                    helperTips
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            actionBar
        }
        .background(T.paper)
        .onAppear { urlFocused = true }
    }

    // ── Header ──────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recipe import")
                    .font(AppFont.text(11, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(T.ink3)
                Text("From a link")
                    .font(AppFont.text(24, weight: .bold))
                    .kerning(-0.7)
                    .foregroundStyle(T.ink)
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
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var intro: some View {
        Text("Paste any recipe URL — Claude reads the page and turns it into a recipe you can edit, add to a week, or pull onto your grocery list.")
            .font(AppFont.text(13))
            .foregroundStyle(T.ink2)
            .lineSpacing(2)
    }

    // ── URL field ───────────────────────────

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            TextField("smittenkitchen.com/...", text: $url)
                .font(AppFont.mono(13))
                .foregroundStyle(T.ink)
                .tint(T.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(T.paperDeep)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.rule, lineWidth: 1))
                )
                .focused($urlFocused)
                .submitLabel(.go)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { runImport() }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(T.warn)
                .padding(.top, 1)
            Text(msg)
                .font(AppFont.text(12))
                .foregroundStyle(T.ink2)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(T.warn.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.warn.opacity(0.4), lineWidth: 1))
        )
    }

    private var helperTips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKS WELL WITH")
                .font(AppFont.text(10.5, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            tip("Recipe blogs (Smitten Kitchen, NYT Cooking, Half Baked Harvest, etc.)")
            tip("Most food sites with structured recipe markup")
            tip("Pages where you can see the full recipe (no paywall)")
        }
        .padding(.top, 8)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(T.accent).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(AppFont.text(12))
                .foregroundStyle(T.ink2)
        }
    }

    // ── Action bar ─────────────────────────

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                runImport()
            } label: {
                HStack(spacing: 8) {
                    if importing {
                        ProgressView().controlSize(.small).tint(T.accentInk)
                    } else {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(importing ? "Importing…" : "Import recipe")
                        .font(AppFont.text(13, weight: .semibold))
                }
                .foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(canImport ? T.accent : T.rule))
            }
            .buttonStyle(.plain)
            .disabled(!canImport || importing)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, 12)
        .background(
            T.paper
                .overlay(alignment: .top) {
                    Rectangle().fill(T.ruleSoft).frame(height: 1)
                }
        )
    }

    private var canImport: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ── Action ─────────────────────────────

    private func runImport() {
        guard canImport else {
            if state.anthropicApiKey.isEmpty {
                errorMsg = "Add your Anthropic API key in Settings → AI Vision first. Recipe import uses the same key."
            }
            return
        }
        importing = true
        errorMsg = nil
        let urlString = url
        let key = state.anthropicApiKey
        Task {
            do {
                let meal = try await RecipeImporter.importFrom(urlString: urlString, apiKey: key)
                await MainActor.run {
                    state.customMeals.removeAll { $0.id == meal.id }
                    state.customMeals.append(meal)
                    importedMealId = meal.id
                    importing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMsg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    importing = false
                }
            }
        }
    }
}
