import SwiftUI
import PhotosUI

struct ImportRecipeSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// Set after a successful import — parent uses it to open RecipeDetail.
    @Binding var importedMealId: String?

    enum Mode: String, CaseIterable, Identifiable {
        case url, photo, text
        var id: String { rawValue }
        var label: String {
            switch self {
            case .url:   return "URL"
            case .photo: return "Photo"
            case .text:  return "Text"
            }
        }
    }

    @State private var mode: Mode = .url
    @State private var url: String = ""
    @State private var pastedText: String = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var pickedImage: Data? = nil
    @State private var pickedThumb: Image? = nil
    @State private var importing: Bool = false
    @State private var errorMsg: String? = nil
    @FocusState private var urlFocused: Bool
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    modeToggle
                    switch mode {
                    case .url:   urlField
                    case .photo: photoField
                    case .text:  textField
                    }
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
        .onAppear { if mode == .url { urlFocused = true } }
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
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var intro: some View {
        Text("Paste a URL or pick a photo of any recipe — Claude turns it into one you can edit, add to a week, or pull onto your grocery list.")
            .font(AppFont.text(13))
            .foregroundStyle(T.ink2)
            .lineSpacing(2)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        mode = m
                        errorMsg = nil
                    }
                    if m == .url { urlFocused = true }
                    if m == .text { textFocused = true }
                } label: {
                    Text(m.label)
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundStyle(mode == m ? T.paper : T.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(mode == m ? T.ink : Color.clear)
                        )
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(T.paperDeep)
        )
    }

    private var textField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECIPE TEXT")
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            TextEditor(text: $pastedText)
                .font(AppFont.text(13))
                .foregroundStyle(T.ink)
                .tint(T.ink)
                .focused($textFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200, maxHeight: 320)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(T.paperDeep)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.rule, lineWidth: 1))
                )
                .overlay(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("Paste recipe text here…\n\ne.g. ingredient list + steps from a paywalled NYT Cooking page, an email from a friend, or a hand-typed family recipe.")
                            .font(AppFont.text(12))
                            .foregroundStyle(T.ink3)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECIPE PHOTO")
                .font(AppFont.text(11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(T.ink3)
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    if let img = pickedThumb {
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(T.ink3)
                            Text("Tap to pick a photo")
                                .font(AppFont.text(13, weight: .semibold))
                                .foregroundStyle(T.ink2)
                            Text("Cookbook page, magazine, screenshot")
                                .font(AppFont.text(11))
                                .foregroundStyle(T.ink3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .padding(.vertical, 22)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(T.paperDeep)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(T.rule, style: StrokeStyle(lineWidth: 1, dash: pickedThumb == nil ? [4, 3] : []))
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        pickedImage = data
                        if let ui = UIImage(data: data) {
                            pickedThumb = Image(uiImage: ui)
                        }
                    }
                }
            }
            if pickedThumb != nil {
                Button {
                    pickedImage = nil
                    pickedThumb = nil
                    pickerItem = nil
                } label: {
                    Text("Pick a different photo")
                        .font(AppFont.text(11, weight: .semibold))
                        .foregroundStyle(T.ink3)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
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
        let keyOK = !state.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch mode {
        case .url:   return keyOK && !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo: return keyOK && pickedImage != nil
        case .text:  return keyOK && !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // ── Action ─────────────────────────────

    private func runImport() {
        guard canImport else {
            if state.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMsg = "Add your Anthropic API key in Settings → AI Vision first. Recipe import uses the same key."
            }
            return
        }
        importing = true
        errorMsg = nil
        let key = state.anthropicApiKey
        let currentMode = mode
        let urlString = url
        let imageData = pickedImage
        Task {
            do {
                let meal: Meal
                switch currentMode {
                case .url:
                    meal = try await RecipeImporter.importFrom(urlString: urlString, apiKey: key)
                case .photo:
                    guard let data = imageData else { throw RecipeImporter.ImportError.noContent }
                    meal = try await RecipeImporter.importFromPhoto(imageData: data, apiKey: key)
                case .text:
                    meal = try await RecipeImporter.importFromText(text: pastedText, apiKey: key)
                }
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
