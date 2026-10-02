import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
    }
}
