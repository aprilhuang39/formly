import Vision
import AVFoundation
import QuartzCore

protocol PoseEstimating: AnyObject {
    func estimate(in sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> PoseFrame
}

final class VisionPoseEstimator: PoseEstimating {
    func estimate(in sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) async throws -> PoseFrame {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation)
        try handler.perform([request])
        guard let observation = request.results?.first else { return PoseFrame(timestamp: CACurrentMediaTime(), joints: [:]) }
        let mapping: [Joint: VNHumanBodyPoseObservation.JointName] = [
            .nose:.nose, .neck:.neck, .leftShoulder:.leftShoulder, .rightShoulder:.rightShoulder,
            .leftHip:.leftHip, .rightHip:.rightHip, .leftKnee:.leftKnee, .rightKnee:.rightKnee,
            .leftAnkle:.leftAnkle, .rightAnkle:.rightAnkle
        ]
        let recognized = try observation.recognizedPoints(.all)
        let joints = mapping.reduce(into: [Joint: JointPoint]()) { result, pair in
            guard let p = recognized[pair.value], p.confidence > 0.15 else { return }
            result[pair.key] = JointPoint(x: p.location.x, y: 1 - p.location.y, confidence: p.confidence)
        }
        return PoseFrame(timestamp: CACurrentMediaTime(), joints: joints)
    }
}
