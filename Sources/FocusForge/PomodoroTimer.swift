import Foundation

public enum PomodoroError: Error, Equatable, Sendable {
    case invalidTransition(String)
    case invalidConfiguration(String)
}

/// Timer configuration. All durations in whole minutes.
public struct PomodoroConfig: Codable, Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    /// Take a long break after this many focus sessions.
    public var sessionsBeforeLongBreak: Int

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        sessionsBeforeLongBreak: Int = 4
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak
    }

    public func validated() throws {
        guard (1...180).contains(focusMinutes) else {
            throw PomodoroError.invalidConfiguration("Focus length must be 1–180 minutes.")
        }
        guard (1...60).contains(shortBreakMinutes) else {
            throw PomodoroError.invalidConfiguration("Short break must be 1–60 minutes.")
        }
        guard (1...90).contains(longBreakMinutes) else {
            throw PomodoroError.invalidConfiguration("Long break must be 1–90 minutes.")
        }
        guard (2...12).contains(sessionsBeforeLongBreak) else {
            throw PomodoroError.invalidConfiguration("Sessions before long break must be 2–12.")
        }
    }
}

/// The timer's phase. `paused` is a wrapper: `pausedFrom` remembers the
/// underlying phase so resume restores it exactly.
public enum PomodoroPhase: String, Codable, Sendable, Equatable {
    case idle
    case focus
    case shortBreak
    case longBreak
    case paused

    public var label: String {
        switch self {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        case .paused: return "Paused"
        }
    }

    public var isBreak: Bool {
        self == .shortBreak || self == .longBreak
    }
}

/// A pure state machine for the Pomodoro technique.
///
/// Valid transitions:
/// - idle → focus (start)
/// - focus/shortBreak/longBreak → paused (pause)
/// - paused → previous phase (resume)
/// - any → idle (reset)
/// - focus → shortBreak/longBreak, breaks → focus (automatic on tick, or skip)
///
/// The machine is time-source agnostic: the UI (or a widget) drives it with
/// `tick(seconds:)`, which makes it fully deterministic in tests.
public struct PomodoroTimer: Equatable, Sendable {
    public private(set) var phase: PomodoroPhase
    public private(set) var remainingSeconds: Int
    /// Focus sessions finished in the current cycle; resets after a long break.
    public private(set) var completedSessionsInCycle: Int
    /// The phase we were in before pausing. Non-nil only while `phase == .paused`.
    public private(set) var pausedFrom: PomodoroPhase?
    public var config: PomodoroConfig

    public init(config: PomodoroConfig = PomodoroConfig()) {
        self.config = config
        self.phase = .idle
        self.remainingSeconds = 0
        self.completedSessionsInCycle = 0
        self.pausedFrom = nil
    }

    /// Total length of the current phase in seconds (0 when idle).
    public var totalSecondsForCurrentPhase: Int {
        switch effectivePhase {
        case .idle: return 0
        case .focus: return config.focusMinutes * 60
        case .shortBreak: return config.shortBreakMinutes * 60
        case .longBreak: return config.longBreakMinutes * 60
        case .paused: return 0 // unreachable: effectivePhase never returns .paused
        }
    }

    /// 0–1 progress through the current phase.
    public var progress: Double {
        let total = totalSecondsForCurrentPhase
        guard total > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(total)
    }

    /// The underlying phase while paused (nil unless paused).
    public var effectivePhase: PomodoroPhase {
        phase == .paused ? (pausedFrom ?? .idle) : phase
    }

    // MARK: - Transitions

    public mutating func start() throws {
        guard phase == .idle else {
            throw PomodoroError.invalidTransition("Can only start from idle.")
        }
        try config.validated()
        phase = .focus
        remainingSeconds = config.focusMinutes * 60
    }

    public mutating func pause() throws {
        switch phase {
        case .focus, .shortBreak, .longBreak:
            pausedFrom = phase
            phase = .paused
        default:
            throw PomodoroError.invalidTransition("Can only pause an active phase.")
        }
    }

    public mutating func resume() throws {
        guard phase == .paused, let previous = pausedFrom else {
            throw PomodoroError.invalidTransition("Can only resume from pause.")
        }
        phase = previous
        pausedFrom = nil
    }

    /// Back to idle. Keeps the cycle count so a mid-day reset doesn't disturb
    /// the long-break cadence; use `startNewCycle()` to reset that too.
    public mutating func reset() {
        phase = .idle
        remainingSeconds = 0
        pausedFrom = nil
    }

    public mutating func startNewCycle() {
        reset()
        completedSessionsInCycle = 0
    }

    /// Ends the current phase immediately and moves to the next one.
    public mutating func skip() throws {
        switch phase {
        case .focus, .shortBreak, .longBreak:
            advancePhase()
        case .paused:
            phase = pausedFrom ?? .focus
            pausedFrom = nil
            advancePhase()
        case .idle:
            throw PomodoroError.invalidTransition("Nothing to skip while idle.")
        }
    }

    /// Advances the clock. When a phase hits zero it rolls into the next one
    /// automatically; leftover seconds carry over into the new phase.
    public mutating func tick(seconds: Int = 1) {
        guard seconds > 0 else { return }
        guard phase == .focus || phase == .shortBreak || phase == .longBreak else { return }
        var left = seconds
        while left > 0 && (phase == .focus || phase == .shortBreak || phase == .longBreak) {
            if remainingSeconds > left {
                remainingSeconds -= left
                left = 0
            } else {
                left -= remainingSeconds
                advancePhase()
            }
        }
    }

    // MARK: - Private

    private mutating func advancePhase() {
        switch phase {
        case .focus:
            completedSessionsInCycle += 1
            if completedSessionsInCycle % config.sessionsBeforeLongBreak == 0 {
                phase = .longBreak
                remainingSeconds = config.longBreakMinutes * 60
            } else {
                phase = .shortBreak
                remainingSeconds = config.shortBreakMinutes * 60
            }
        case .shortBreak:
            phase = .focus
            remainingSeconds = config.focusMinutes * 60
        case .longBreak:
            completedSessionsInCycle = 0
            phase = .focus
            remainingSeconds = config.focusMinutes * 60
        case .idle, .paused:
            break
        }
    }
}
