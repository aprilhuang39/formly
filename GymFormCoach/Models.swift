import Foundation
import CoreGraphics

enum Joint: String, CaseIterable, Codable {
    case nose, neck, leftShoulder, rightShoulder, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle
}

struct JointPoint: Codable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct PoseFrame: Sendable {
    let timestamp: TimeInterval
    let joints: [Joint: JointPoint]
}

struct AngleSample: Identifiable, Codable, Sendable {
    let id: UUID
    let elapsed: TimeInterval
    let knee: Double
    let hip: Double
    let torsoLean: Double

    init(elapsed: TimeInterval, knee: Double, hip: Double, torsoLean: Double) {
        id = UUID(); self.elapsed = elapsed; self.knee = knee; self.hip = hip; self.torsoLean = torsoLean
    }
}

enum FormCue: String, Codable, Sendable {
    case goDeeper = "Aim a little deeper"
    case chestUp = "Keep your chest up"
    case kneesAligned = "Keep your knee aligned"
    case standTall = "Stand tall at the top"
}

struct AnalysisResult: Sendable {
    var exerciseName = "Position yourself"
    var isRecognized = false
    var reps = 0
    var currentKneeAngle = 180.0
    var rangeOfMotion = 0.0
    var formScore = 100
    var cue: FormCue?
    var sample: AngleSample?
}

struct WorkoutSession: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let exercise: String
    let reps: Int
    let rangeOfMotion: Double
    let formScore: Int
    let samples: [AngleSample]
}
