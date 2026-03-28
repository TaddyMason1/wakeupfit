import AVFoundation
import Combine
import UIKit
import Vision

final class CameraManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isSessionRunning = false
    @Published var showMoveBackPrompt = false
    @Published var error: String?

    // MARK: - Session
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.wakeupfit.camera")
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?

    // MARK: - Zoom
    private let minZoomFactor: CGFloat = 1.0
    private var defaultZoomFactor: CGFloat = 1.0
    private var missingJointFrameCount = 0
    private let missingJointThreshold = 15 // ~0.5s at 30fps before zoom adjustment

    // MARK: - Pose Callback
    var onFrame: ((CMSampleBuffer) -> Void)?

    // MARK: - Setup

    func configure() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    // MARK: - Auto-Zoom

    /// Called by PoseDetector each frame with body visibility status
    func updateBodyVisibility(allJointsVisible: Bool) {
        guard let device = currentDevice else { return }

        if allJointsVisible {
            missingJointFrameCount = 0
            DispatchQueue.main.async { self.showMoveBackPrompt = false }

            // Smoothly zoom back to default if we had zoomed out
            if device.videoZoomFactor < defaultZoomFactor {
                smoothZoom(to: defaultZoomFactor)
            }
        } else {
            missingJointFrameCount += 1

            if missingJointFrameCount > missingJointThreshold {
                let currentZoom = device.videoZoomFactor
                let targetZoom = max(device.minAvailableVideoZoomFactor, currentZoom - 0.1)

                if currentZoom > device.minAvailableVideoZoomFactor {
                    smoothZoom(to: targetZoom)
                } else {
                    DispatchQueue.main.async { self.showMoveBackPrompt = true }
                }
            }
        }
    }

    // MARK: - Private

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Prefer ultra-wide front camera if available, else default front
        let device: AVCaptureDevice?
        if let ultraWide = AVCaptureDevice.default(
            .builtInUltraWideCamera,
            for: .video,
            position: .front
        ) {
            device = ultraWide
        } else {
            device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            )
        }

        guard let camera = device else {
            DispatchQueue.main.async { self.error = "No front camera available" }
            session.commitConfiguration()
            return
        }

        currentDevice = camera
        defaultZoomFactor = camera.videoZoomFactor

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.wakeupfit.videoframes"))

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            // Configure video data output connection
            // DO NOT mirror — the preview layer auto-mirrors for front camera.
            // We only set orientation so the buffer arrives in portrait format.
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Explicitly do not mirror — Vision needs the raw (non-mirrored) buffer
                // to produce correct coordinates. The skeleton overlay will mirror X
                // to match the preview layer's auto-mirror.
                connection.isVideoMirrored = false
            }
        } catch {
            DispatchQueue.main.async { self.error = error.localizedDescription }
        }

        session.commitConfiguration()
    }

    private func smoothZoom(to factor: CGFloat) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: factor, withRate: 2.0)
            device.unlockForConfiguration()
        } catch {
            // Silently fail zoom — non-critical
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
