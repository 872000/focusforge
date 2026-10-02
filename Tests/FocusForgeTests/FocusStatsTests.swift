import XCTest
@testable import FocusForge

final class FocusStatsTests: XCTestCase {

    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        return cal
    }()

    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testRecordSessionAggregatesPerDay() {
        var stats = FocusStats()
        let monday = day(2026, 10, 5)
        stats.recordSession(on: monday, focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: monday, focusSeconds: 1500, tasksCompleted: 1, calendar: calendar)
        let log = stats.log(for: monday, calendar: calendar)!
        XCTAssertEqual(log.sessionsCompleted, 2)
        XCTAssertEqual(log.focusSeconds, 3000)
        XCTAssertEqual(log.tasksCompleted, 1)
        XCTAssertEqual(stats.focusMinutes(on: monday, calendar: calendar), 50, accuracy: 0.001)
    }

    func testStreakCountsConsecutiveDays() {
        var stats = FocusStats()
        // Sessions Mon, Tue, Wed.
        for d in 5...7 {
            stats.recordSession(on: day(2026, 10, d), focusSeconds: 1500, calendar: calendar)
        }
        XCTAssertEqual(stats.streak(asOf: day(2026, 10, 7), calendar: calendar), 3)
    }

    func testStreakBreaksOnGap() {
        var stats = FocusStats()
        stats.recordSession(on: day(2026, 10, 5), focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: day(2026, 10, 7), focusSeconds: 1500, calendar: calendar) // skipped the 6th
        XCTAssertEqual(stats.streak(asOf: day(2026, 10, 7), calendar: calendar), 1)
    }

    func testStreakSurvivesBeforeFirstSessionOfDay() {
        var stats = FocusStats()
        stats.recordSession(on: day(2026, 10, 5), focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: day(2026, 10, 6), focusSeconds: 1500, calendar: calendar)
        // It's Oct 7 and no session yet today: streak still reads 2, not 0.
        XCTAssertEqual(stats.streak(asOf: day(2026, 10, 7), calendar: calendar), 2)
    }

    func testStreakZeroWhenNeverActive() {
        let stats = FocusStats()
        XCTAssertEqual(stats.streak(asOf: day(2026, 10, 7), calendar: calendar), 0)
    }

    func testLastNDaysFillsGaps() {
        var stats = FocusStats()
        stats.recordSession(on: day(2026, 10, 5), focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: day(2026, 10, 7), focusSeconds: 3000, calendar: calendar)
        let last3 = stats.lastNDays(3, asOf: day(2026, 10, 7), calendar: calendar)
        XCTAssertEqual(last3.count, 3)
        XCTAssertEqual(last3.map(\.sessionsCompleted), [1, 0, 1])
        // Oldest first.
        XCTAssertEqual(last3.first?.day, calendar.startOfDay(for: day(2026, 10, 5)))
    }

    func testTotals() {
        var stats = FocusStats()
        stats.recordSession(on: day(2026, 10, 5), focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: day(2026, 10, 6), focusSeconds: 3000, calendar: calendar)
        XCTAssertEqual(stats.totalSessions, 2)
        XCTAssertEqual(stats.totalFocusMinutes, 75, accuracy: 0.001)
    }

    func testJSONRoundTrip() throws {
        var stats = FocusStats()
        stats.recordSession(on: day(2026, 10, 5), focusSeconds: 1500, calendar: calendar)
        let restored = try FocusStats.decodeFromJSON(stats.encodeToJSON())
        XCTAssertEqual(restored, stats)
    }
}

final class WidgetSupportTests: XCTestCase {

    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        return cal
    }()

    func testWidgetSnapshotFromTimer() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        timer.tick(seconds: 15)

        var stats = FocusStats()
        let now = Date()
        stats.recordSession(on: now, focusSeconds: 1500, calendar: calendar)
        stats.recordSession(on: now, focusSeconds: 1500, calendar: calendar)

        let task = FocusTask(title: "Write report")
        let snapshot = FocusWidgetSnapshot.make(timer: timer, currentTask: task, stats: stats, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.phase, .focus)
        XCTAssertEqual(snapshot.remainingSeconds, 45)
        XCTAssertEqual(snapshot.totalSeconds, 60)
        XCTAssertEqual(snapshot.currentTaskTitle, "Write report")
        XCTAssertEqual(snapshot.sessionsToday, 2)
        XCTAssertEqual(snapshot.streakDays, 1)
        XCTAssertEqual(snapshot.progress, 0.25, accuracy: 0.0001)
    }

    func testWidgetSnapshotWhilePausedUsesEffectivePhase() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        try timer.pause()
        let snapshot = FocusWidgetSnapshot.make(
            timer: timer, currentTask: nil, stats: FocusStats(), now: Date(), calendar: calendar
        )
        XCTAssertEqual(snapshot.phase, .focus, "snapshot reports the underlying phase, not .paused")
    }

    func testLiveActivityStateEndsAt() throws {
        var timer = PomodoroTimer(config: testConfig())
        try timer.start()
        let now = Date()
        let state = FocusLiveActivityState.make(
            timer: timer, currentTask: nil, stats: FocusStats(), now: now, calendar: calendar
        )
        XCTAssertEqual(state.phase, .focus)
        let endsAt = try XCTUnwrap(state.endsAt)
        XCTAssertEqual(endsAt.timeIntervalSince(now), 60, accuracy: 1.0)
    }

    func testLiveActivityStateNilEndsAtWhenIdle() {
        let timer = PomodoroTimer(config: testConfig())
        let state = FocusLiveActivityState.make(
            timer: timer, currentTask: nil, stats: FocusStats(), now: Date(), calendar: calendar
        )
        XCTAssertNil(state.endsAt)
    }
}
