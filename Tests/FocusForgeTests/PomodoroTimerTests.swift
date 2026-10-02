import XCTest
@testable import FocusForge

/// Tiny config for fast tests: 5s focus, 2s short break, 3s long break,
/// long break every 2 sessions. (Durations are minutes; tick() drives time.)
func testConfig() -> PomodoroConfig {
    PomodoroConfig(focusMinutes: 1, shortBreakMinutes: 1, longBreakMinutes: 2, sessionsBeforeLongBreak: 2)
}

final class PomodoroTimerTests: XCTestCase {

    func testStartsFromIdle() throws {
        var timer = PomodoroTimer(config: testConfig())
        XCTAssertEqual(timer.phase, .idle)
        try timer.start()
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertEqual(timer.remainingSeconds, 60)
    }

    func testCannotStartTwice() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        XCTAssertThrowsError(try timer.start()) { error in
            XCTAssertEqual(error as? PomodoroError, .invalidTransition("Can only start from idle."))
        }
    }

    func testPauseAndResume() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        try timer.pause()
        XCTAssertEqual(timer.phase, .paused)
        XCTAssertEqual(timer.pausedFrom, .focus)
        XCTAssertEqual(timer.effectivePhase, .focus)

        try timer.resume()
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertNil(timer.pausedFrom)
    }

    func testCannotPauseWhenIdle() {
        var timer = PomodoroTimer()
        XCTAssertThrowsError(try timer.pause())
    }

    func testCannotResumeWithoutPause() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        XCTAssertThrowsError(try timer.resume())
    }

    func testTickCountsDown() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 10)
        XCTAssertEqual(timer.remainingSeconds, 50)
        XCTAssertEqual(timer.phase, .focus)
    }

    func testCompletingFocusMovesToShortBreak() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 60) // full focus session
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.remainingSeconds, 60)
        XCTAssertEqual(timer.completedSessionsInCycle, 1)
    }

    func testLongBreakEveryNSessions() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 60)   // focus 1 -> short break
        XCTAssertEqual(timer.phase, .shortBreak)
        timer.tick(seconds: 60)   // short break -> focus
        XCTAssertEqual(timer.phase, .focus)
        timer.tick(seconds: 60)   // focus 2 -> long break (every 2)
        XCTAssertEqual(timer.phase, .longBreak)
        XCTAssertEqual(timer.remainingSeconds, 120)
    }

    func testLongBreakResetsCycle() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 60 + 60 + 60) // focus, short break, focus -> long break
        XCTAssertEqual(timer.phase, .longBreak)
        timer.tick(seconds: 120) // long break -> focus, cycle resets
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertEqual(timer.completedSessionsInCycle, 0)
    }

    func testTickCarriesLeftoverSeconds() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 90) // 60s focus + 30s into short break
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.remainingSeconds, 30)
    }

    func testTickDoesNothingWhenIdleOrPaused() throws {
        var timer = PomodoroTimer(config: testConfig())
        timer.tick(seconds: 10)
        XCTAssertEqual(timer.phase, .idle)

        try timer.start()
        try timer.pause()
        timer.tick(seconds: 10)
        XCTAssertEqual(timer.remainingSeconds, 60, "paused timer must not advance")
    }

    func testSkipFocus() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        try timer.skip()
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.completedSessionsInCycle, 1)
    }

    func testSkipBreak() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 60)
        try timer.skip() // skip short break -> back to focus
        XCTAssertEqual(timer.phase, .focus)
    }

    func testSkipWhileIdleThrows() {
        var timer = PomodoroTimer(config: testConfig())
        XCTAssertThrowsError(try timer.skip())
    }

    func testReset() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 60)
        timer.reset()
        XCTAssertEqual(timer.phase, .idle)
        XCTAssertEqual(timer.remainingSeconds, 0)
        XCTAssertNil(timer.pausedFrom)
        XCTAssertEqual(timer.completedSessionsInCycle, 1, "reset keeps the cycle count")
    }

    func testProgress() throws {
        var timer = PomodoroTimer(config: testConfig())
        XCTAssertEqual(timer.progress, 0)
        try timer.start()
        XCTAssertEqual(timer.progress, 0, accuracy: 0.001)
        timer.tick(seconds: 30)
        XCTAssertEqual(timer.progress, 0.5, accuracy: 0.001)
    }

    func testInvalidConfigRejectedOnStart() {
        var timer = PomodoroTimer(config: PomodoroConfig(focusMinutes: 0))
        XCTAssertThrowsError(try timer.start()) { error in
            XCTAssertEqual(
                error as? PomodoroError,
                .invalidConfiguration("Focus length must be 1–180 minutes.")
            )
        }
    }

    func testConfigValidationBounds() {
        XCTAssertNoThrow(try PomodoroConfig().validated())
        XCTAssertThrowsError(try PomodoroConfig(sessionsBeforeLongBreak: 1).validated())
        XCTAssertThrowsError(try PomodoroConfig(shortBreakMinutes: 61).validated())
    }
}
