import AVFoundation
import SwiftUI

/// Wraps an `AVCaptureSession` for the Snap viewfinder. Single-purpose:
/// request access, attach the back camera input, start/stop the session,
/// and capture a still photo on shutter tap.
@MainActor
@Observable
final class CameraSession {
    let session = AVCaptureSession()
    var status: Status = .checking

    enum Status {
        case checking         // permission not yet resolved
        case authorized       // session running
        case denied           // user denied or restricted
        case unavailable      // simulator / no camera hardware
    }

    private var configured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDelegate: PhotoCaptureDelegate?

    /// Capture a still photo as JPEG `Data`. Returns nil if the session isn't
    /// authorized or the device fails to produce a frame.
    func capturePhoto() async -> Data? {
        guard status == .authorized else { return nil }
        return await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegate { data in
                continuation.resume(returning: data)
            }
            self.captureDelegate = delegate   // retain — AVFoundation only weak-holds it
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// Resolve permissions, configure the session if needed, and start it.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await runIfPossible()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await runIfPossible() }
            else { status = .denied }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .denied
        }
    }

    func stop() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }

    // ── Internals ───────────────────────────────────

    private func runIfPossible() async {
        if !configured {
            configured = configureSession()
        }
        guard configured else {
            status = .unavailable
            return
        }
        if !session.isRunning {
            await Task.detached(priority: .userInitiated) { [session] in
                session.startRunning()
            }.value
        }
        status = .authorized
    }

    /// Adds the back camera input + photo output. Returns false on simulator / hardware miss.
    private func configureSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device else { return false }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            return true
        } catch {
            return false
        }
    }
}

/// Bridges AVCapturePhotoOutput's delegate callback to a closure.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Data?) -> Void
    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Photo capture failed:", error)
            completion(nil)
            return
        }
        completion(photo.fileDataRepresentation())
    }
}

// MARK: - Preview view

/// SwiftUI bridge to AVCaptureVideoPreviewLayer. Backs a UIView whose layer
/// is the preview layer itself, so resize/orientation are free.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoLayer.session = session
        v.videoLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
