import SwiftUI
import FocusForge

// MARK: - Timer

@Observable
final class TimerViewModel {
    var timer = PomodoroTimer()
    var currentTaskID: UUID?
    var lastError: String?

    private var ticker: Timer?

    init() {
        if let data = UserDefaults.standard.data(forKey: "focusforge.config"),
           let config = try? JSONDecoder().decode(PomodoroConfig.self, from: data) {
            timer.config = config
        }
    }

    func saveConfig() {
        try? JSONEncoder().encode(timer.config).map {
            UserDefaults.standard.set($0, forKey: "focusforge.config")
        }
    }

    var isRunning: Bool {
        timer.phase == .focus || timer.phase == .shortBreak || timer.phase == .longBreak
    }

    func start() {
        do {
            try timer.start()
            startTicker()
        } catch {
            lastError = (error as? PomodoroError).map(friendlyMessage) ?? error.localizedDescription
        }
    }

    func pause() { try? timer.pause(); stopTicker() }
    func reset() { timer.reset(); stopTicker() }

    func resume() {
        do {
            try timer.resume()
            startTicker()
        } catch {
            lastError = (error as? PomodoroError).map(friendlyMessage) ?? error.localizedDescription
        }
    }

    func skip() { try? timer.skip() }

    /// Call when a focus phase finishes naturally — records the session.
    var onFocusPhaseCompleted: ((Int) -> Void)?

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let wasPhase = self.timer.phase
            self.timer.tick()
            // A focus phase just ended when we left focus for a break phase.
            if wasPhase == .focus && self.timer.phase.isBreak {
                self.onFocusPhaseCompleted?(self.timer.config.focusMinutes * 60)
            }
            if self.timer.phase == .idle { self.stopTicker() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func friendlyMessage(for error: PomodoroError) -> String {
        switch error {
        case .invalidTransition(let message): return message
        case .invalidConfiguration(let message): return message
        }
    }
}

// MARK: - Tasks

@Observable
final class TasksViewModel {
    var list = TaskList()

    private let tasksURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("focusforge-tasks.json")
    }()

    init() { load() }

    func add(_ task: FocusTask) { list.add(task); save() }
    func update(_ task: FocusTask) { list.update(task); save() }
    func remove(_ task: FocusTask) { list.remove(id: task.id); save() }

    func recordPomodoro(for taskID: UUID) {
        guard var task = list.tasks.first(where: { $0.id == taskID }) else { return }
        task.recordPomodoro()
        list.update(task)
        save()
    }

    private func save() {
        try? list.encodeToJSON().write(to: tasksURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: tasksURL),
              let decoded = try? TaskList.decodeFromJSON(data) else { return }
        list = decoded
    }
}

// MARK: - Stats

@Observable
final class StatsViewModel {
    var stats = FocusStats()

    private let statsURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("focusforge-stats.json")
    }()

    init() { load() }

    func recordSession(focusSeconds: Int) {
        stats.recordSession(on: Date(), focusSeconds: focusSeconds)
        save()
    }

    private func save() {
        try? stats.encodeToJSON().write(to: statsURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: statsURL),
              let decoded = try? FocusStats.decodeFromJSON(data) else { return }
        stats = decoded
    }
}
