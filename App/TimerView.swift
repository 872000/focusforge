import SwiftUI
import FocusForge

struct TimerView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(TasksViewModel.self) private var tasksVM
    @Environment(StatsViewModel.self) private var statsVM

    @State private var showingConfig = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                phaseLabel

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    Circle()
                        .trim(from: 0, to: timerVM.timer.progress)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerVM.timer.remainingSeconds)
                    VStack {
                        Text(timeString)
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                        Text(sessionInfo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)
                .padding(.top, 8)

                if let task = currentTask {
                    Label(task.title, systemImage: "target")
                        .font(.headline)
                }

                controlButtons
                Spacer()
            }
            .padding()
            .navigationTitle("FocusForge")
            .toolbar {
                Button { showingConfig = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showingConfig) {
                TimerConfigView()
            }
            .onAppear {
                timerVM.onFocusPhaseCompleted = { focusSeconds in
                    statsVM.recordSession(focusSeconds: focusSeconds)
                    if let id = timerVM.currentTaskID {
                        tasksVM.recordPomodoro(for: id)
                    }
                }
            }
            .alert("Timer",
                   isPresented: Binding(
                    get: { timerVM.lastError != nil },
                    set: { if !$0 { timerVM.lastError = nil } }
                   )) {
                Button("OK", role: .cancel) { timerVM.lastError = nil }
            } message: {
                Text(timerVM.lastError ?? "")
            }
        }
    }

    private var currentTask: FocusTask? {
        guard let id = timerVM.currentTaskID else { return nil }
        return tasksVM.list.tasks.first { $0.id == id }
    }

    private var phaseLabel: some View {
        Text(timerVM.timer.effectivePhase.label)
            .font(.title2.bold())
            .foregroundStyle(phaseColor)
    }

    private var phaseColor: Color {
        switch timerVM.timer.effectivePhase {
        case .focus: return .orange
        case .shortBreak, .longBreak: return .green
        case .idle, .paused: return .blue
        }
    }

    private var timeString: String {
        let s = timerVM.timer.remainingSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private var sessionInfo: String {
        let done = timerVM.timer.completedSessionsInCycle
        let total = timerVM.timer.config.sessionsBeforeLongBreak
        return "Session \(min(done + 1, total)) of \(total)"
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 16) {
            switch timerVM.timer.phase {
            case .idle:
                Button("Start Focus") { timerVM.start() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            case .paused:
                Button("Resume") { timerVM.resume() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Reset", role: .destructive) { timerVM.reset() }
                    .buttonStyle(.bordered)
            case .focus, .shortBreak, .longBreak:
                Button("Pause") { timerVM.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Skip") { timerVM.skip() }
                    .buttonStyle(.bordered)
                Button("Reset", role: .destructive) { timerVM.reset() }
                    .buttonStyle(.bordered)
            }
        }
    }
}

struct TimerConfigView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(\.dismiss) private var dismiss

    @State private var focusMinutes: Int = 25
    @State private var shortBreakMinutes: Int = 5
    @State private var longBreakMinutes: Int = 15
    @State private var sessionsBeforeLongBreak: Int = 4

    var body: some View {
        NavigationStack {
            Form {
                Section("Durations (minutes)") {
                    Stepper("Focus: \(focusMinutes)", value: $focusMinutes, in: 1...180)
                    Stepper("Short break: \(shortBreakMinutes)", value: $shortBreakMinutes, in: 1...60)
                    Stepper("Long break: \(longBreakMinutes)", value: $longBreakMinutes, in: 1...90)
                    Stepper("Sessions before long break: \(sessionsBeforeLongBreak)",
                            value: $sessionsBeforeLongBreak, in: 2...12)
                }
                Section {
                    Text("Changes apply to the next session. The current timer keeps running untouched.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        timerVM.timer.config = PomodoroConfig(
                            focusMinutes: focusMinutes,
                            shortBreakMinutes: shortBreakMinutes,
                            longBreakMinutes: longBreakMinutes,
                            sessionsBeforeLongBreak: sessionsBeforeLongBreak
                        )
                        timerVM.saveConfig()
                        dismiss()
                    }
                }
            }
            .onAppear {
                let config = timerVM.timer.config
                focusMinutes = config.focusMinutes
                shortBreakMinutes = config.shortBreakMinutes
                longBreakMinutes = config.longBreakMinutes
                sessionsBeforeLongBreak = config.sessionsBeforeLongBreak
            }
        }
    }
}
