import SwiftUI
import FocusForge

struct StatsView: View {
    @Environment(StatsViewModel.self) private var statsVM
    @Environment(TasksViewModel.self) private var tasksVM

    var body: some View {
        NavigationStack {
            let now = Date()
            let stats = statsVM.stats
            let last7 = stats.lastNDays(7, asOf: now)
            let maxMinutes = max(1, last7.map { Double($0.focusSeconds) / 60 }.max() ?? 1)

            List {
                Section {
                    HStack(spacing: 24) {
                        StatTile(
                            value: "\(stats.streak(asOf: now))",
                            label: "day streak",
                            icon: "flame.fill",
                            color: .orange
                        )
                        StatTile(
                            value: "\(stats.sessions(on: now))",
                            label: "today",
                            icon: "timer",
                            color: .blue
                        )
                        StatTile(
                            value: String(format: "%.0f", stats.focusMinutes(on: now)),
                            label: "min today",
                            icon: "clock",
                            color: .green
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Last 7 days") {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(last7, id: \.day) { log in
                            VStack {
                                let minutes = Double(log.focusSeconds) / 60
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(minutes > 0 ? Color.blue : Color.gray.opacity(0.2))
                                    .frame(height: max(4, CGFloat(minutes / maxMinutes) * 120))
                                Text(dayLetter(for: log.day))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 4)
                }

                Section("All time") {
                    LabeledContent("Total sessions", value: "\(stats.totalSessions)")
                    LabeledContent("Total focus time", value: String(format: "%.1f h", stats.totalFocusMinutes / 60))
                    LabeledContent("Tasks completed", value: "\(tasksVM.list.completedTasks.count)")
                    LabeledContent("Task completion", value: String(format: "%.0f%%", tasksVM.list.completionRate * 100))
                }
            }
            .navigationTitle("Stats")
        }
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
