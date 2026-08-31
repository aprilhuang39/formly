# Gym Form Coach

An iOS 17 SwiftUI MVP that analyzes bodyweight squats entirely on-device.

## Run

1. Open `GymFormCoach.xcodeproj` in Xcode 16 or newer.
2. Select a physical iPhone (the Simulator has no useful live camera feed).
3. Set your development team under Signing & Capabilities and run.
4. Place the phone side-on, with the whole body visible, then tap **Start workout**.

The app does not record or upload video. Vision pose points are processed in memory; completed session summaries are stored locally as JSON.

## Architecture

`CameraService → VisionPoseEstimator → ExerciseAnalyzer → WorkoutViewModel → SwiftUI`

- `PoseEstimating` isolates Apple Vision and can be replaced by a Core ML estimator.
- `ExerciseAnalyzing` makes each exercise a separate temporal state machine.
- `SquatAnalyzer` smooths angles, recognizes a squat stance, counts down/up transitions, scores range of motion, and emits cooldown-controlled form cues.
- `SessionStore` persists only derived workout metrics.

The MVP is intentionally a coaching aid, not a medical or injury-prevention device. Thresholds are starting points and should be calibrated against representative users before production use.
