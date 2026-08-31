import SwiftUI
import AVFoundation
import Vision
import AudioToolbox

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var analysis = AnalysisResult()
    @Published var joints: [Joint: JointPoint] = [:]
    @Published var isActive = false
    @Published var history: [WorkoutSession] = []
    @Published var cameraDenied = false
    @Published var cameraUnavailable = false

    let camera = CameraService()
    private let estimator: PoseEstimating
    private let analyzer: ExerciseAnalyzing
    private let store = SessionStore()
    private var samples: [AngleSample] = []
    private var processing = false

    init(estimator: PoseEstimating = VisionPoseEstimator(), analyzer: ExerciseAnalyzing = SquatAnalyzer()) {
        self.estimator = estimator; self.analyzer = analyzer
        camera.delegate = self
        history = store.load()
    }

    func start() async {
        analyzer.reset(); samples = []; analysis = AnalysisResult()
        cameraDenied = false; cameraUnavailable = false
        do {
            try await camera.requestAndStart()
            isActive = true
        } catch CameraService.CameraError.permissionDenied {
            isActive = false; cameraDenied = true
        } catch {
            isActive = false; cameraUnavailable = true
        }
    }

    func finish() {
        guard isActive else { return }
        camera.stop(); isActive = false
        let session = WorkoutSession(id: UUID(), date: Date(), exercise: analyzer.displayName,
                                     reps: analysis.reps, rangeOfMotion: analysis.rangeOfMotion,
                                     formScore: analysis.formScore, samples: downsample(samples))
        history.insert(session, at: 0); store.save(history)
    }

    private func downsample(_ values: [AngleSample]) -> [AngleSample] {
        let stride = max(1, values.count / 180)
        return values.enumerated().compactMap { $0.offset.isMultiple(of: stride) ? $0.element : nil }
    }
}

extension WorkoutViewModel: CameraServiceDelegate {
    nonisolated func cameraService(_ service: CameraService, didOutput buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        Task { @MainActor [weak self] in
            guard let self, isActive, !processing else { return }
            processing = true
            defer { processing = false }
            do {
                let frame = try await estimator.estimate(in: buffer, orientation: orientation)
                joints = frame.joints
                let result = analyzer.analyze(frame)
                analysis = result
                if let sample = result.sample { samples.append(sample) }
                if result.cue != nil { AudioServicesPlaySystemSound(1104) }
            } catch { }
        }
    }
}

final class SessionStore {
    private var url: URL { URL.documentsDirectory.appending(path: "workouts.json") }
    func load() -> [WorkoutSession] { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([WorkoutSession].self, from: $0) } ?? [] }
    func save(_ sessions: [WorkoutSession]) { if let data = try? JSONEncoder().encode(sessions) { try? data.write(to: url, options: .atomic) } }
}
