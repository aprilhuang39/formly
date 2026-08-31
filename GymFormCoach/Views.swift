import SwiftUI
import AVFoundation
import Charts

struct RootView: View {
    @EnvironmentObject var model: WorkoutViewModel
    var body: some View {
        TabView {
            CoachView().tabItem { Label("Coach", systemImage: "figure.strengthtraining.traditional") }
            HistoryView().tabItem { Label("History", systemImage: "chart.xyaxis.line") }
        }.tint(.mint)
    }
}

struct CoachView: View {
    @EnvironmentObject var model: WorkoutViewModel
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.07).ignoresSafeArea()
            if model.isActive { CameraPreview(session: model.camera.session).ignoresSafeArea(); PoseOverlay(joints: model.joints) }
            VStack(spacing: 16) {
                HStack { StatusPill(text: model.analysis.isRecognized ? "SQUAT DETECTED" : "GET IN FRAME"); Spacer(); Text("ON DEVICE").font(.caption.bold()).foregroundStyle(.white.opacity(0.7)) }
                Spacer()
                if !model.isActive {
                    VStack(spacing: 14) {
                        Image(systemName: "figure.squat").font(.system(size: 64)).foregroundStyle(.mint)
                        Text("Your real-time squat coach").font(.title.bold()).foregroundStyle(.white)
                        Text("Set your phone side-on so your full body stays visible.").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                    }.padding(30)
                } else {
                    if let cue = model.analysis.cue { Text(cue.rawValue).font(.title2.bold()).padding().background(.orange, in: Capsule()) }
                    HStack(spacing: 12) {
                        MetricCard(value: "\(model.analysis.reps)", label: "REPS")
                        MetricCard(value: "\(Int(model.analysis.currentKneeAngle))°", label: "KNEE")
                        MetricCard(value: "\(model.analysis.formScore)", label: "FORM")
                    }
                }
                Button(model.isActive ? "Finish workout" : "Start workout") {
                    if model.isActive { model.finish() } else { Task { await model.start() } }
                }.buttonStyle(CoachButtonStyle(active: model.isActive))
            }.padding()
        }
        .alert("Camera access is off", isPresented: $model.cameraDenied) { Button("OK") {} } message: { Text("Enable Camera access in Settings to use live coaching.") }
        .alert("Camera unavailable", isPresented: $model.cameraUnavailable) { Button("OK") {} } message: { Text("A back camera could not be started. Try again on a physical iPhone.") }
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: WorkoutViewModel
    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty { ContentUnavailableView("No workouts yet", systemImage: "figure.squat", description: Text("Complete a coached workout to see your trends.")) }
                else { List(model.history) { session in NavigationLink { SessionDetail(session: session) } label: { SessionRow(session: session) } } }
            }.navigationTitle("Progress")
        }
    }
}

struct SessionDetail: View {
    let session: WorkoutSession
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            HStack { MetricCard(value: "\(session.reps)", label: "REPS"); MetricCard(value: "\(Int(session.rangeOfMotion))°", label: "ROM"); MetricCard(value: "\(session.formScore)", label: "FORM") }
            Text("Joint angles").font(.title2.bold())
            Chart(session.samples) { sample in
                LineMark(x: .value("Time", sample.elapsed), y: .value("Knee", sample.knee)).foregroundStyle(.mint)
                LineMark(x: .value("Time", sample.elapsed), y: .value("Hip", sample.hip)).foregroundStyle(.purple)
            }.chartYAxisLabel("Degrees").frame(height: 260)
            Text("Mint: knee  •  Purple: hip").font(.caption).foregroundStyle(.secondary)
        }.padding() }.navigationTitle(session.exercise).navigationBarTitleDisplayMode(.inline)
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    var body: some View { HStack { VStack(alignment: .leading) { Text(session.exercise).font(.headline); Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(session.reps) reps").bold(); Text("\(session.formScore)").foregroundStyle(.mint).bold() } }
}

struct MetricCard: View {
    let value: String, label: String
    var body: some View { VStack { Text(value).font(.title.bold()); Text(label).font(.caption2.bold()).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
}

struct StatusPill: View {
    let text: String
    var body: some View { Text(text).font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 12).padding(.vertical, 7).background(.mint, in: Capsule()) }
}

struct CoachButtonStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).frame(maxWidth: .infinity).padding().background(active ? Color.red : Color.mint, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.black).opacity(configuration.isPressed ? 0.7 : 1) }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.layerSession.session = session; view.layerSession.videoGravity = .resizeAspectFill; return view }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView { override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }; var layerSession: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer } }

struct PoseOverlay: View {
    let joints: [Joint: JointPoint]
    private let bones: [(Joint, Joint)] = [(.leftShoulder,.rightShoulder),(.leftShoulder,.leftHip),(.rightShoulder,.rightHip),(.leftHip,.rightHip),(.leftHip,.leftKnee),(.leftKnee,.leftAnkle),(.rightHip,.rightKnee),(.rightKnee,.rightAnkle)]
    var body: some View { Canvas { context, size in
        for bone in bones { if let a=joints[bone.0], let b=joints[bone.1] { var path=Path(); path.move(to: CGPoint(x:a.x*size.width,y:a.y*size.height)); path.addLine(to: CGPoint(x:b.x*size.width,y:b.y*size.height)); context.stroke(path, with:.color(.mint), lineWidth:4) } }
        for point in joints.values { context.fill(Path(ellipseIn:CGRect(x:point.x*size.width-5,y:point.y*size.height-5,width:10,height:10)), with:.color(.white)) }
    }.allowsHitTesting(false) }
}
