import SwiftUI

/// Full-bleed camera viewfinder. Shows a live AVFoundation preview when the user
/// has granted access; falls back to a dark mock with a hint on simulator / denied.
/// The shutter triggers the same fixture cycle the Snap button used.
struct CameraViewfinder: View {
    let snapsToday: Int
    let onCancel: () -> Void
    /// Receives the captured JPEG `Data`, or nil if capture was skipped/failed.
    let onShutter: (Data?) -> Void

    @State private var camera = CameraSession()
    @State private var capturing = false
    private static let bg = Color(hex: 0x16110d)

    var body: some View {
        ZStack {
            // Background — paper-dark, in case nothing else covers it.
            Self.bg.ignoresSafeArea()

            // Live camera feed when authorized.
            if camera.status == .authorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                fallbackMessage
            }

            // Vignette so the reticle reads against any background.
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.45)],
                center: .center, startRadius: 100, endRadius: 500
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            reticle

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    @ViewBuilder
    private var fallbackMessage: some View {
        VStack(spacing: 10) {
            Image(systemName: camera.status == .denied ? "camera.fill.badge.ellipsis" : "camera.viewfinder")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(T.paper.opacity(0.6))
            Text(fallbackTitle)
                .font(AppFont.text(14, weight: .semibold))
                .foregroundStyle(T.paper.opacity(0.9))
            Text(fallbackBody)
                .font(AppFont.text(12))
                .foregroundStyle(T.paper.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if camera.status == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(AppFont.text(13, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(T.paper))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private var fallbackTitle: String {
        switch camera.status {
        case .checking:    return "Setting up camera"
        case .denied:      return "Camera access is off"
        case .unavailable: return "Camera not available"
        case .authorized:  return ""
        }
    }

    private var fallbackBody: String {
        switch camera.status {
        case .checking:    return "Hang on a sec…"
        case .denied:      return "Allow camera access in Settings to scan meals."
        case .unavailable: return "The simulator doesn't have a camera. Tap the shutter to test the analyzing flow with a sample meal."
        case .authorized:  return ""
        }
    }

    // ── Reticle ─────────────────────────────────────

    private var reticle: some View {
        ZStack {
            // Corner brackets framing the focus area.
            ForEach(0..<4, id: \.self) { idx in
                CornerBracket()
                    .stroke(T.paper.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(idx) * 90))
                    .offset(
                        x: idx == 1 || idx == 2 ? 110 : -110,
                        y: idx >= 2 ? 110 : -110
                    )
            }
            // Center dot
            Circle()
                .stroke(T.paper.opacity(0.6), lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }

    // ── Top bar ─────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(AppFont.text(14, weight: .semibold))
                    .foregroundStyle(T.paper)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11))
                Text("\(snapsToday) today")
                    .font(AppFont.mono(11, weight: .semibold))
            }
            .foregroundStyle(T.paper.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.10)))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // ── Bottom bar ──────────────────────────────────

    private var bottomBar: some View {
        HStack(alignment: .center) {
            // Gallery picker (decorative for v0)
            Button {} label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(T.paper.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()

            // Shutter
            Button {
                guard !capturing else { return }
                capturing = true
                Task {
                    let data = await camera.capturePhoto()
                    capturing = false
                    onShutter(data)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(T.paper, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(T.paper)
                        .frame(width: 60, height: 60)
                    if capturing {
                        ProgressView().tint(T.ink)
                    }
                }
            }
            .buttonStyle(ShutterPress())
            .disabled(capturing)

            Spacer()
            // Settings (decorative)
            Button {} label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(T.paper.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}

private struct ShutterPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}
