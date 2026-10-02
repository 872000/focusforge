import Foundation

/// One day's worth of focus activity. `day` is start-of-day.
public struct DayLog: Codable, Equatable, Sendable {
    public var day: Date
    public var focusSeconds: Int
    public var sessionsCompleted: Int
    public var tasksCompleted: Int

    public init(day: Date, focusSeconds: Int, sessionsCompleted: Int, tasksCompleted: Int) {
        self.day = day
        self.focusSeconds = focusSeconds
        self.sessionsCompleted = sessionsCompleted
        self.tasksCompleted = tasksCompleted
    }
}

/// Daily focus statistics and streaks. Pure value type — encode to JSON to persist.
public struct FocusStats: Codable, Equatable, Sendable {
    public private(set) var logs: [DayLog]

    public init(logs: [DayLog] = []) {
        self.logs = logs
    }

    /// Records one finished focus session on the day containing `date`.
    public mutating func recordSession(
        on date: Date,
        focusSeconds: Int,
        tasksCompleted: Int = 0,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        if let index = logs.firstIndex(where: { $0.day == day }) {
            logs[index].focusSeconds += focusSeconds
            logs[index].sessionsCompleted += 1
            logs[index].tasksCompleted += tasksCompleted
        } else {
            logs.append(DayLog(
                day: day,
                focusSeconds: focusSeconds,
                sessionsCompleted: 1,
                tasksCompleted: tasksCompleted
            ))
        }
    }

    public func log(for date: Date, calendar: Calendar = .current) -> DayLog? {
        let day = calendar.startOfDay(for: date)
        return logs.first { $0.day == day }
    }

    public func sessions(on date: Date, calendar: Calendar = .current) -> Int {
        log(for: date, calendar: calendar)?.sessionsCompleted ?? 0
    }

    public func focusMinutes(on date: Date, calendar: Calendar = .current) -> Double {
        Double(log(for: date, calendar: calendar)?.focusSeconds ?? 0) / 60
    }

    /// Consecutive active days (≥1 session) ending at `date`.
    ///
    /// If `date` itself has no sessions yet, the streak is counted back from
    /// the previous day, so the streak doesn't read as broken before the
    /// first session of the day.
    public func streak(asOf date: Date, calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: date)
        if sessions(on: cursor, calendar: calendar) == 0 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
                  sessions(on: previous, calendar: calendar) > 0 else {
                return 0
            }
            cursor = previous
        }
        var count = 0
        while sessions(on: cursor, calendar: calendar) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Logs for the last `n` days ending at `date`, oldest first. Days with no
    /// activity are represented by zero-filled logs so charts stay continuous.
    public func lastNDays(_ n: Int, asOf date: Date, calendar: Calendar = .current) -> [DayLog] {
        let today = calendar.startOfDay(for: date)
        return (0..<n).reversed().compactMap { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return log(for: day, calendar: calendar)
                ?? DayLog(day: day, focusSeconds: 0, sessionsCompleted: 0, tasksCompleted: 0)
        }
    }

    public var totalSessions: Int {
        logs.reduce(0) { $0 + $1.sessionsCompleted }
    }

    public var totalFocusMinutes: Double {
        Double(logs.reduce(0) { $0 + $1.focusSeconds }) / 60
    }

    // MARK: - Persistence helpers

    public func encodeToJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decodeFromJSON(_ data: Data) throws -> FocusStats {
        try JSONDecoder().decode(FocusStats.self, from: data)
    }
}
