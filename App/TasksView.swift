import SwiftUI
import FocusForge

struct TasksView: View {
    @Environment(TasksViewModel.self) private var tasksVM
    @Environment(TimerViewModel.self) private var timerVM

    @State private var showingForm = false
    @State private var editingTask: FocusTask?

    var body: some View {
        NavigationStack {
            List {
                let tasks = tasksVM.list.prioritized()
                if tasks.isEmpty {
                    Section {
                        Text("No tasks yet. Add one and attach it to your next focus session.")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(tasks) { task in
                    TaskRow(
                        task: task,
                        isCurrent: timerVM.currentTaskID == task.id,
                        onToggleDone: { toggleDone(task) },
                        onSelectForTimer: {
                            timerVM.currentTaskID = (timerVM.currentTaskID == task.id) ? nil : task.id
                        }
                    )
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            tasksVM.remove(task)
                            if timerVM.currentTaskID == task.id { timerVM.currentTaskID = nil }
                        }
                        Button("Edit") { editingTask = task }
                            .tint(.blue)
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                Button { showingForm = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingForm) { TaskFormView(task: nil) }
            .sheet(item: $editingTask) { task in TaskFormView(task: task) }
        }
    }

    private func toggleDone(_ task: FocusTask) {
        var updated = task
        if updated.isCompleted { updated.reopen() } else { updated.markCompleted() }
        tasksVM.update(updated)
    }
}

struct TaskRow: View {
    let task: FocusTask
    let isCurrent: Bool
    let onToggleDone: () -> Void
    let onSelectForTimer: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggleDone) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    PriorityBadge(priority: task.priority)
                }
                HStack(spacing: 4) {
                    ForEach(0..<task.estimatedPomodoros, id: \.self) { index in
                        Image(systemName: index < task.completedPomodoros ? "circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(index < task.completedPomodoros ? .orange : .secondary)
                    }
                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !task.isCompleted {
                Button(action: onSelectForTimer) {
                    Image(systemName: isCurrent ? "timer.circle.fill" : "timer.circle")
                        .foregroundStyle(isCurrent ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

struct TaskFormView: View {
    @Environment(TasksViewModel.self) private var tasksVM
    @Environment(\.dismiss) private var dismiss

    let existing: FocusTask?

    @State private var title: String
    @State private var priority: TaskPriority
    @State private var estimatedPomodoros: Int

    init(task: FocusTask?) {
        self.existing = task
        _title = State(initialValue: task?.title ?? "")
        _priority = State(initialValue: task?.priority ?? .medium)
        _estimatedPomodoros = State(initialValue: task?.estimatedPomodoros ?? 2)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $title)
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                Stepper("Estimated pomodoros: \(estimatedPomodoros)",
                        value: $estimatedPomodoros, in: 1...16)
            }
            .navigationTitle(existing == nil ? "Add Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        if var existing {
            existing.title = title
            existing.priority = priority
            existing.estimatedPomodoros = estimatedPomodoros
            tasksVM.update(existing)
        } else {
            tasksVM.add(FocusTask(title: title, priority: priority, estimatedPomodoros: estimatedPomodoros))
        }
        dismiss()
    }
}
