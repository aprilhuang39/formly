import SwiftUI

@main
struct GymFormCoachApp: App {
    @StateObject private var model = WorkoutViewModel()

    var body: some Scene {
        WindowGroup { RootView().environmentObject(model) }
    }
}
