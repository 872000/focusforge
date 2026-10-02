import XCTest
@testable import FocusForge

final class FocusTaskTests: XCTestCase {

    func testRecordPomodoro() {
        var task = FocusTask(title: "Write report", estimatedPomodoros: 3)
        task.recordPomodoro()
        task.recordPomodoro()
        XCTAssertEqual(task.completedPomodoros, 2)
        XCTAssertEqual(task.remainingPomodoros, 1)
        XCTAssertEqual(task.progress, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testRecordPomodoroIgnoredWhenCompleted() {
        var task = FocusTask(title: "Done", estimatedPomodoros: 1)
        task.markCompleted()
        task.recordPomodoro()
        XCTAssertEqual(task.completedPomodoros, 0)
    }

    func testCompleteAndReopen() {
        var task = FocusTask(title: "Thing")
        XCTAssertFalse(task.isCompleted)
        task.markCompleted()
        XCTAssertTrue(task.isCompleted)
        task.reopen()
        XCTAssertFalse(task.isCompleted)
    }

    func testEstimatedPomodorosMinimumOne() {
        let task = FocusTask(title: "Thing", estimatedPomodoros: 0)
        XCTAssertEqual(task.estimatedPomodoros, 1)
    }

    func testPrioritizedOrdering() {
        var list = TaskList()
        let now = Date()
        list.add(FocusTask(title: "Low", priority: .low, createdAt: now))
        list.add(FocusTask(title: "Urgent", priority: .urgent, createdAt: now.addingTimeInterval(10)))
        list.add(FocusTask(title: "High", priority: .high, createdAt: now.addingTimeInterval(20)))
        var doneUrgent = FocusTask(title: "Done urgent", priority: .urgent, createdAt: now)
        doneUrgent.markCompleted()
        list.add(doneUrgent)

        let ordered = list.prioritized().map(\.title)
        XCTAssertEqual(ordered, ["Urgent", "High", "Low", "Done urgent"])
    }

    func testCompletionRate() {
        var list = TaskList()
        XCTAssertEqual(list.completionRate, 0)
        var a = FocusTask(title: "A")
        var b = FocusTask(title: "B")
        b.markCompleted()
        list.add(a)
        list.add(b)
        XCTAssertEqual(list.completionRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(list.openTasks.count, 1)
        XCTAssertEqual(list.completedTasks.count, 1)
    }

    func testUpdateAndRemove() {
        var list = TaskList()
        var task = FocusTask(title: "Original")
        list.add(task)
        task.title = "Renamed"
        list.update(task)
        XCTAssertEqual(list.tasks.first?.title, "Renamed")
        list.remove(id: task.id)
        XCTAssertTrue(list.tasks.isEmpty)
    }

    func testJSONRoundTrip() throws {
        var list = TaskList()
        list.add(FocusTask(title: "A", priority: .high, estimatedPomodoros: 4))
        let restored = try TaskList.decodeFromJSON(list.encodeToJSON())
        XCTAssertEqual(restored, list)
    }
}
