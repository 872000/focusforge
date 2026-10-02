import Foundation

// MARK: - Widget & Live Activity support
//
// WidgetKit and ActivityKit only exist on Apple platforms, so the live objects
// (`TimelineEntry`, `ActivityContent.State`) live in the Xcode app target.
// These pure-data structs are the bridge: the app target maps them 1:1 into
// the real WidgetKit/ActivityKit types, and they stay fully testable here.

/// Snapshot describing the timer for a WidgetKit timeline entry.
public struct FocusWidgetSnapshot: Codable, Equatable, Sendable {
    public var phase: PomodoroPhase
    public var remainingSeconds: Int
    public var totalSeconds: Int
    public var currentTaskTitle: String?
    public var sessionsToday: Int
    public var streakDays: Int
    public var lastUpdated: Date

    public init(
        phase: PomodoroPhase,
        remainingSeconds: Int,
        totalSeconds: Int,
        currentTaskTitle: String?,
        sessionsToday: Int,
        streakDays: Int,
        lastUpdated: Date
    ) {
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.totalSeconds = totalSeconds
        self.currentTaskTitle = currentTaskTitle
        self.sessionsToday = sessionsToday
        self.streakDays = streakDays
        self.lastUpdated = lastUpdated
    }

    public static func make(
        timer: PomodoroTimer,
        currentTask: FocusTask?,
        stats: FocusStats,
        now: Date,
        calendar: Calendar = .current
    ) -> FocusWidgetSnapshot {
        FocusWidgetSnapshot(
            phase: timer.effectivePhase,
            remainingSeconds: timer.remainingSeconds,
            totalSeconds: timer.totalSecondsForCurrentPhase,
            currentTaskTitle: currentTask?.title,
            sessionsToday: stats.sessions(on: now, calendar: calendar),
            streakDays: stats.streak(asOf: now, calendar: calendar),
            lastUpdated: now
        )
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(totalSeconds)
    }
}

/// Mirrors the fields an ActivityKit `ActivityContent.State` would carry for
/// the FocusForge Live Activity. In the app target, hand these values to the
/// real `ContentState`; `endsAt` lets the Live Activity count down on the
/// lock screen without further updates.
public struct FocusLiveActivityState: Codable, Equatable, Sendable {
    public var phase: PomodoroPhase
    /// Wall-clock time the current phase finishes. Nil when idle or paused.
    public var endsAt: Date?
    public var taskTitle: String?
    public var sessionsToday: Int

    public init(phase: PomodoroPhase, endsAt: Date?, taskTitle: String?, sessionsToday: Int) {
        self.phase = phase
        self.endsAt = endsAt
        self.taskTitle = taskTitle
        self.sessionsToday = sessionsToday
    }

    public static func make(
        timer: PomodoroTimer,
        currentTask: FocusTask?,
        stats: FocusStats,
        now: Date,
        calendar: Calendar = .current
    ) -> FocusLiveActivityState {
        let isActive = timer.phase == .focus || timer.phase == .shortBreak || timer.phase == .longBreak
        return FocusLiveActivityState(
            phase: timer.effectivePhase,
            endsAt: isActive ? now.addingTimeInterval(TimeInterval(timer.remainingSeconds)) : nil,
            taskTitle: currentTask?.title,
            sessionsToday: stats.sessions(on: now, calendar: calendar)
        )
    }
}
