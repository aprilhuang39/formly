import Foundation
import CoreGraphics

protocol ExerciseAnalyzing: AnyObject {
    var displayName: String { get }
    func analyze(_ frame: PoseFrame) -> AnalysisResult
    func reset()
}

enum Geometry {
    static func angle(_ a: CGPoint, _ vertex: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: c.x - vertex.x, dy: c.y - vertex.y)
        let denominator = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard denominator > 0.0001 else { return 180 }
        return acos(max(-1, min(1, (v1.dx * v2.dx + v1.dy * v2.dy) / denominator))) * 180 / .pi
    }

    static func angleFromVertical(_ upper: CGPoint, _ lower: CGPoint) -> Double {
        abs(atan2(upper.x - lower.x, upper.y - lower.y)) * 180 / .pi
    }
}

final class SquatAnalyzer: ExerciseAnalyzing {
    let displayName = "Bodyweight Squat"
    private enum Phase { case standing, descending, bottom, ascending }
    private var phase: Phase = .standing
    private var reps = 0
    private var smoothedKnee = 180.0
    private var minimumKnee = 180.0
    private var formEvents = 0
    private var lastCueTime = -10.0
    private var startTime: TimeInterval?
    private var reachedDepth = false
    private var previousKnee = 180.0

    func reset() {
        phase = .standing; reps = 0; smoothedKnee = 180; minimumKnee = 180
        formEvents = 0; lastCueTime = -10; startTime = nil
        reachedDepth = false; previousKnee = 180
    }

    func analyze(_ frame: PoseFrame) -> AnalysisResult {
        startTime = startTime ?? frame.timestamp
        let elapsed = frame.timestamp - (startTime ?? frame.timestamp)
        guard let side = bestVisibleSide(frame.joints) else { return AnalysisResult() }
        let shoulder = side.0.point, hip = side.1.point, knee = side.2.point, ankle = side.3.point
        let kneeAngle = Geometry.angle(hip, knee, ankle)
        let hipAngle = Geometry.angle(shoulder, hip, knee)
        let torsoLean = Geometry.angleFromVertical(shoulder, hip)
        smoothedKnee = 0.28 * kneeAngle + 0.72 * smoothedKnee

        let recognized = hip.distance(to: knee) > 0.08 && knee.distance(to: ankle) > 0.08
        if recognized { updatePhase(kneeAngle: smoothedKnee) }
        previousKnee = smoothedKnee
        minimumKnee = min(minimumKnee, smoothedKnee)
        let cue = recognized ? formCue(knee: knee, ankle: ankle, torso: torsoLean, hipAngle: hipAngle, time: frame.timestamp) : nil
        let rom = max(0, 180 - minimumKnee)
        let score = max(0, 100 - formEvents * 8)
        return AnalysisResult(exerciseName: recognized ? displayName : "Position yourself", isRecognized: recognized,
                              reps: reps, currentKneeAngle: smoothedKnee, rangeOfMotion: rom,
                              formScore: score, cue: cue,
                              sample: AngleSample(elapsed: elapsed, knee: smoothedKnee, hip: hipAngle, torsoLean: torsoLean))
    }

    private func updatePhase(kneeAngle: Double) {
        let isExtending = kneeAngle > previousKnee + 0.8
        switch phase {
        case .standing where kneeAngle < 155:
            phase = .descending; minimumKnee = kneeAngle; reachedDepth = false
        case .descending where kneeAngle < 108:
            phase = .bottom; reachedDepth = true
        case .descending where isExtending && kneeAngle > minimumKnee + 8:
            phase = .ascending
        case .bottom where kneeAngle > 118:
            phase = .ascending
        case .ascending where kneeAngle > 160:
            if reachedDepth { reps += 1 }
            phase = .standing
        default: break
        }
    }

    private func formCue(knee: CGPoint, ankle: CGPoint, torso: Double, hipAngle: Double, time: TimeInterval) -> FormCue? {
        guard time - lastCueTime > 2.5 else { return nil }
        let cue: FormCue?
        if smoothedKnee < 145 && abs(knee.x - ankle.x) > 0.13 { cue = .kneesAligned }
        else if smoothedKnee < 130 && torso > 42 { cue = .chestUp }
        else if phase == .ascending && smoothedKnee > 160 && hipAngle < 155 { cue = .standTall }
        else if phase == .ascending && !reachedDepth && smoothedKnee > 140 { cue = .goDeeper }
        else { cue = nil }
        if cue != nil { lastCueTime = time; formEvents += 1 }
        return cue
    }

    private func bestVisibleSide(_ joints: [Joint: JointPoint]) -> (JointPoint, JointPoint, JointPoint, JointPoint)? {
        let sides: [(Joint, Joint, Joint, Joint)] = [(.leftShoulder,.leftHip,.leftKnee,.leftAnkle),(.rightShoulder,.rightHip,.rightKnee,.rightAnkle)]
        return sides.compactMap { names -> (JointPoint, JointPoint, JointPoint, JointPoint)? in
            guard let a=joints[names.0], let b=joints[names.1], let c=joints[names.2], let d=joints[names.3],
                  min(a.confidence,b.confidence,c.confidence,d.confidence) > 0.25 else { return nil }
            return (a,b,c,d)
        }.max { lhs, rhs in
            [lhs.0,lhs.1,lhs.2,lhs.3].map(\.confidence).reduce(0,+) < [rhs.0,rhs.1,rhs.2,rhs.3].map(\.confidence).reduce(0,+)
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }
}
