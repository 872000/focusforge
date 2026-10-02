import Foundation

public enum TaskPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

/// A task worked on in Pomodoro sessions.
public struct FocusTask: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var priority: TaskPriority
    public var estimatedPomodoros: Int
    public var completedPomodoros: Int
    public var isCompleted: Bool
    public var createdAt: Date
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        priority: TaskPriority = .medium,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.estimatedPomodoros = max(1, estimatedPomodoros)
        self.completedPomodoros = completedPomodoros
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.notes = notes
    }

    public var remainingPomodoros: Int {
        max(0, estimatedPomodoros - completedPomodoros)
    }

    /// 0–1 progress toward the estimate.
    public var progress: Double {
        guard estimatedPomodoros > 0 else { return 0 }
        return min(1, Double(completedPomodoros) / Double(estimatedPomodoros))
    }

    public mutating func recordPomodoro() {
        guard !isCompleted else { return }
        completedPomodoros += 1
    }

    public mutating func markCompleted() {
        isCompleted = true
    }

    public mutating func reopen() {
        isCompleted = false
    }
}

/// The task list. Pure value type — encode to JSON to persist.
public struct TaskList: Codable, Equatable, Sendable {
    public private(set) var tasks: [FocusTask]

    public init(tasks: [FocusTask] = []) {
        self.tasks = tasks
    }

    public mutating func add(_ task: FocusTask) {
        tasks.append(task)
    }

    public mutating func remove(id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    public mutating func update(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }

    /// Highest priority first, then oldest first. Completed tasks sink to the bottom.
    public func prioritized() -> [FocusTask] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public var openTasks: [FocusTask] {
        tasks.filter { !$0.isCompleted }
    }

    public var completedTasks: [FocusTask] {
        tasks.filter(\.isCompleted)
    }

    public var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count)
    }

    // MARK: - Persistence helpers

    public func encodeToJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decodeFromJSON(_ data: Data) throws -> TaskList {
        try JSONDecoder().decode(TaskList.self, from: data)
    }
}
