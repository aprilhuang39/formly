import AVFoundation
import ImageIO
import Combine

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

final class CameraService: NSObject, ObservableObject {
    enum CameraError: Error { case permissionDenied, unavailable, configurationFailed }

    let session = AVCaptureSession()
    weak var delegate: CameraServiceDelegate?
    private let queue = DispatchQueue(label: "coach.camera")
    private let output = AVCaptureVideoDataOutput()
    private var isConfigured = false

    func requestAndStart() async throws {
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard granted else { throw CameraError.permissionDenied }
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }
                do {
                    try self.configureAndStart()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() { queue.async { [weak self] in self?.session.stopRunning() } }

    private func configureAndStart() throws {
        guard !session.isRunning else { return }
        if !isConfigured {
            session.beginConfiguration(); session.sessionPreset = .high
            do {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device) else { throw CameraError.unavailable }
                guard session.canAddInput(input) else { throw CameraError.configurationFailed }
                session.addInput(input)
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: queue)
                guard session.canAddOutput(output) else { throw CameraError.configurationFailed }
                session.addOutput(output)
                output.connection(with: .video)?.videoRotationAngle = 90
                session.commitConfiguration()
                isConfigured = true
            } catch {
                session.commitConfiguration()
                throw error
            }
        }
        session.startRunning()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraService(self, didOutput: sampleBuffer, orientation: .right)
    }
}
