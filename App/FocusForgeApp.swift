import SwiftUI

@main
struct FocusForgeApp: App {
    @State private var timerVM = TimerViewModel()
    @State private var tasksVM = TasksViewModel()
    @State private var statsVM = StatsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerVM)
                .environment(tasksVM)
                .environment(statsVM)
        }
    }
}
