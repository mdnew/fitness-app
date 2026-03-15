import SwiftUI
import UniformTypeIdentifiers
import HealthKit
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            TrackScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Track", systemImage: "stopwatch")
                }

            ActivityScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Activity", systemImage: "figure.strengthtraining.traditional")
                }

            RoutineScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            SettingsScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
    }
}

private struct PlannedActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let initialItem: PlannedActivityItem
    let onSave: (PlannedActivityItem) -> Void

    @State private var activityType: String
    @State private var date: Date

    init(initialItem: PlannedActivityItem, onSave: @escaping (PlannedActivityItem) -> Void) {
        self.initialItem = initialItem
        self.onSave = onSave
        _activityType = State(initialValue: initialItem.activityType)
        _date = State(initialValue: initialItem.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity Type", text: $activityType)
                }

                Section("Date") {
                    DatePicker(
                        "When",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationTitle("Planned Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedType = activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedType.isEmpty else { return }
                        onSave(
                            PlannedActivityItem(
                                id: initialItem.id,
                                activityType: trimmedType,
                                date: date
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GoalsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var draggedGoal: GoalItem?
    @State private var isAddingGoal = false

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                HStack {
                    SectionTitle(title: "Goals")
                    Spacer()
                    Button {
                        isAddingGoal = true
                    } label: {
                        Label("Add Activity", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                if store.goals.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No goals yet")
                                .font(.headline)

                            Text("Add an activity manually, or connect Apple Health and use History to pull an activity into this list.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            WideActionButton(title: "Add Activity", tint: .blue) {
                                isAddingGoal = true
                            }
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("Drag to reorder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    AppCard {
                        VStack(spacing: 10) {
                            ForEach(Array(store.goals.enumerated()), id: \.element.id) { index, goal in
                                GoalRow(
                                    index: index + 1,
                                    goal: goal,
                                    onDelete: {
                                        store.removeGoal(id: goal.id)
                                        store.persist()
                                    }
                                )
                                .onDrag {
                                    draggedGoal = goal
                                    return NSItemProvider(object: goal.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: GoalDropDelegate(
                                        targetGoal: goal,
                                        store: store,
                                        draggedGoal: $draggedGoal
                                    )
                                )
                                if index < store.goals.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddingGoal) {
                GoalEditorView(title: "Add Activity") { title, emphasis in
                    if store.addManualGoal(title: title, emphasis: emphasis) {
                        store.persist()
                    }
                }
            }
        }
    }
}

private struct RoutineScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingRoutineActivity: RoutineActivity?
    @State private var isAddingRoutineActivity = false
    @State private var editingPlannedActivity: PlannedActivityItem?

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                SectionTitle(title: "Your Focus")
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose the activity you care most about improving right now. Workout generation will bias exercise choices toward supporting it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Your Focus", selection: focusSelection) {
                            Text("None").tag(String?.none)
                            ForEach(focusActivityOptions, id: \.self) { activityType in
                                Text(activityType).tag(Optional(activityType))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                SectionTitle(title: "Training Activities")
                VStack(spacing: 10) {
                    trainingActivityCard(activityType: "Traditional Strength Training")
                    trainingActivityCard(activityType: "Core Training")
                }

                HStack {
                    SectionTitle(title: "Planned Activities")
                    Spacer()
                    Button {
                        editingPlannedActivity = PlannedActivityItem(
                            id: UUID(),
                            activityType: store.selectedFocusActivityType ?? WorkoutActivityCatalog.titles.first ?? "Traditional Strength Training",
                            date: .now
                        )
                    } label: {
                        Label("Add Planned", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if store.plannedActivities.isEmpty {
                    AppCard {
                        EmptyCardMessage(message: "Create one-off activities on specific dates, like a ski day or race.")
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.plannedActivities.sorted(by: { $0.date < $1.date })) { planned in
                            AppCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(planned.activityType)
                                            .font(.headline)
                                        Text(planned.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    SmallIconButton(systemImage: "pencil") {
                                        editingPlannedActivity = planned
                                    }
                                    SmallIconButton(systemImage: "trash", tint: .red) {
                                        store.plannedActivities.removeAll { $0.id == planned.id }
                                        store.persist()
                                    }
                                }
                            }
                        }
                    }
                }

                HStack {
                    SectionTitle(title: "Recurring Activities")
                    Spacer()
                    Button {
                        isAddingRoutineActivity = true
                    } label: {
                        Label("Add Recurring", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    if store.routineActivities.isEmpty {
                        AppCard {
                            EmptyCardMessage(message: "No plans yet. Add one to create a reusable workout and schedule it on specific weekdays.")
                        }
                    } else {
                        ForEach(recurringRoutineActivities) { routineActivity in
                            routineActivityCard(routineActivity)
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingRoutineActivity) { routineActivity in
                RoutineActivityEditorView(
                    title: routineActivity.isTrainingTemplate ? "Edit Training Activity" : "Edit Plan",
                    initialRoutineActivity: routineActivity,
                    activityTypeOptions: routineActivity.isTrainingTemplate ? [routineActivity.activityType] : routineActivityOptions,
                    isTrainingActivity: routineActivity.isTrainingTemplate,
                    lockedActivityType: routineActivity.isTrainingTemplate ? routineActivity.activityType : nil,
                    allowedBodyAreas: routineActivity.isTrainingTemplate ? allowedTrainingBodyAreas(for: routineActivity.activityType) : nil,
                    onSave: { updatedRoutineActivity in
                        store.upsertRoutineActivity(updatedRoutineActivity)
                        store.persist()
                    }
                )
            }
            .sheet(isPresented: $isAddingRoutineActivity) {
                RoutineActivityEditorView(
                    title: "Add Recurring",
                    initialRoutineActivity: nil,
                    activityTypeOptions: routineActivityOptions,
                    isTrainingActivity: false,
                    lockedActivityType: nil,
                    allowedBodyAreas: nil,
                    onSave: { newRoutineActivity in
                        store.upsertRoutineActivity(newRoutineActivity)
                        store.persist()
                    }
                )
            }
            .sheet(item: $editingPlannedActivity) { planned in
                PlannedActivityEditorView(
                    initialItem: planned,
                    onSave: { updated in
                        if let index = store.plannedActivities.firstIndex(where: { $0.id == updated.id }) {
                            store.plannedActivities[index] = updated
                        } else {
                            store.plannedActivities.append(updated)
                        }
                        store.plannedActivities.sort { $0.date < $1.date }
                        store.persist()
                    }
                )
            }
        }
    }

    private func routineScheduleText(for routineActivity: RoutineActivity) -> String {
        let scheduleSummary = routineActivity.scheduleSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return scheduleSummary.isEmpty ? "Not scheduled yet" : scheduleSummary
    }

    @ViewBuilder
    private func trainingActivityCard(activityType: String) -> some View {
        let existing = store.routineActivities.first {
            $0.isTrainingTemplate &&
            $0.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activityType) == .orderedSame
        }

        let subtitle: String = {
            if let existing {
                return existing.focusSummary
            } else {
                let areas = allowedTrainingBodyAreas(for: activityType)
                return areas.isEmpty ? "" : areas.map(\.title).joined(separator: ", ")
            }
        }()

        AppCard {
            Button {
                let routine = existing ?? RoutineActivity(
                    id: UUID(),
                    title: activityType,
                    activityType: activityType,
                    focusAreas: [],
                    scheduledWeekdays: [],
                    defaultLocationID: nil,
                    defaultDurationMinutes: nil,
                    bodyPartSchedules: [],
                    isTrainingTemplate: true
                )
                editingRoutineActivity = routine
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activityType)
                            .font(.headline)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func routineActivityCard(_ routineActivity: RoutineActivity) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routineActivity.title)
                            .font(.headline)
                        if !routineActivity.focusSummary.isEmpty {
                            Text(routineActivity.focusSummary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        SmallIconButton(systemImage: "pencil") {
                            editingRoutineActivity = routineActivity
                        }

                        SmallIconButton(systemImage: "trash", tint: .red) {
                            store.removeRoutineActivity(id: routineActivity.id)
                            store.persist()
                        }
                    }
                }

                Label(routineScheduleText(for: routineActivity), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            }
        }
    }

    private var focusActivityOptions: [String] {
        Array(
            Set(
                store.recurringActivities
                    .filter(\.isDetectedFromHealth)
                    .map(\.activityType)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        )
        .sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private var focusSelection: Binding<String?> {
        Binding(
            get: { store.selectedFocusActivityType },
            set: { newValue in
                store.setSelectedFocusActivityType(newValue)
                store.persist()
            }
        )
    }

    private var routineActivityOptions: [String] {
        Array(
            Set(
                store.recurringActivities
                    .filter(\.isDetectedFromHealth)
                    .map(\.activityType)
                    .filter { activityType in
                        let trimmed = activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return false }
                        let lowercased = trimmed.lowercased()
                        return lowercased != "traditional strength training" &&
                            lowercased != "core training"
                    }
            )
        )
        .sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private var recurringRoutineActivities: [RoutineActivity] {
        store.routineActivities.filter { !$0.isTrainingTemplate }
    }

    private func allowedTrainingBodyAreas(for activityType: String) -> [ExerciseBodyArea] {
        let normalized = activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "core training" {
            return [.glutes, .abs]
        }

        return ExerciseBodyArea.allCases.filter { area in
            area != .glutes && area != .abs
        }
    }
}

private struct ActivityScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var hasScrolledToToday = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionTitle(title: "Upcoming")
                            if upcomingWorkoutDayGroups.isEmpty {
                                AppCard {
                                    EmptyCardMessage(message: "No upcoming sessions are scheduled from your plan yet.")
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(upcomingWorkoutDayGroups) { group in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(weekdayDateText(for: group.date))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .tracking(0.8)

                                            ForEach(group.strengthEntries) { entry in
                                                AppCard {
                                                    SessionStyleActivityCard(entry: entry, dateLabel: sessionDateLabel(for: entry.date), compactVerticalPadding: true)
                                                }
                                            }

                                            ForEach(group.otherEntries) { entry in
                                                AppCard {
                                                    SessionStyleActivityCard(entry: entry, dateLabel: sessionDateLabel(for: entry.date), compactVerticalPadding: true)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            SectionTitle(title: "Today")
                                .id("activity-today-anchor")

                            if allTodayActivityEntries.isEmpty {
                                AppCard {
                                    EmptyCardMessage(message: "Nothing is planned or imported for today yet.")
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(allTodayActivityEntries) { entry in
                                        if entry.kind == .completed {
                                            NavigationLink {
                                                ActivityEntryDetailScreen(entry: entry)
                                            } label: {
                                                AppCard {
                                                    SessionStyleActivityCard(entry: entry, dateLabel: sessionDateLabel(for: entry.date), showChevron: isStrengthOrCoreActivityTitle(entry.title))
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            AppCard {
                                                SessionStyleActivityCard(entry: entry, dateLabel: sessionDateLabel(for: entry.date))
                                            }
                                        }
                                    }
                                }
                            }

                            SectionTitle(title: "Past")
                            if allPastActivityEntries.isEmpty {
                                AppCard {
                                    EmptyCardMessage(message: pastSessionsEmptyMessage)
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(allPastActivityEntries) { entry in
                                        NavigationLink {
                                            ActivityEntryDetailScreen(entry: entry)
                                        } label: {
                                            AppCard {
                                                SessionStyleActivityCard(entry: entry, dateLabel: sessionDateLabel(for: entry.date), showChevron: isStrengthOrCoreActivityTitle(entry.title))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Color.clear
                                .frame(height: 96)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onAppear {
                        guard !hasScrolledToToday else { return }
                        hasScrolledToToday = true
                        DispatchQueue.main.async {
                            proxy.scrollTo("activity-today-anchor", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var futureEntries: [ActivityEntry] {
        let completedDays = Set(strengthWorkouts.map { calendar.startOfDay(for: $0.date) })

        // Recurring Activities-based upcoming entries (non-training routines).
        let recurringEntries: [ActivityEntry] = store
            .upcomingScheduledRoutineActivities(limit: 6)
            .filter { calendar.startOfDay(for: $0.date) > startOfToday }
            .filter { !completedDays.contains(calendar.startOfDay(for: $0.date)) }
            .map { scheduledActivity in
                ActivityEntry(
                    id: scheduledActivity.id,
                    kind: .planned,
                    workoutID: nil,
                    date: scheduledActivity.date,
                    title: scheduledActivity.routineActivity.activityType,
                    subtitle: scheduledActivity.focusSummary,
                    subtitleTint: .secondary,
                    detail: "",
                    secondLineText: "—",
                    statusTitle: "Recurring",
                    statusTint: .blue,
                    exerciseDetails: [],
                    emptyExerciseMessage: "Suggested exercises are generated when you start a Track session."
                )
            }

        // Training Activities-based upcoming entries (from per-body-part schedules).
        let trainingEntries = trainingFutureEntries(completedDays: completedDays)

        // One-off Planned Activities.
        let plannedEntries = plannedActivitiesFutureEntries(completedDays: completedDays)

        // Merge all types, sort by date (soonest first), then limit so Training and Planned mix with Recurring.
        let combined = recurringEntries + trainingEntries + plannedEntries
        return Array(
            combined
                .sorted { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: $1.date) }
                .prefix(30)
        )
    }

    private func trainingFutureEntries(completedDays: Set<Date>) -> [ActivityEntry] {
        let templates = store.routineActivities.filter(\.isTrainingTemplate)
        guard !templates.isEmpty else { return [] }

        var results: [ActivityEntry] = []

        for offset in 1...21 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: date)
            guard !completedDays.contains(dayStart) else { continue }

            let weekday = store.weekday(for: date)

            for template in templates {
                let scheduledWeekdays = Set(template.bodyPartSchedules.flatMap(\.weekdays))
                guard !scheduledWeekdays.isEmpty, scheduledWeekdays.contains(weekday) else {
                    continue
                }

                // Avoid duplicate entry for same date + activity type.
                let alreadyExists = results.contains(where: { entry in
                    calendar.isDate(entry.date, inSameDayAs: date) &&
                    entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        .caseInsensitiveCompare(template.activityType) == .orderedSame
                })
                if alreadyExists { continue }

                let subtitle = isTraditionalStrengthActivityType(template.activityType) ? "" : template.focusSummary

                let entry = ActivityEntry(
                    id: "training-\(template.id.uuidString)-\(dayStart.timeIntervalSince1970)",
                    kind: .planned,
                    workoutID: nil,
                    date: date,
                    title: template.activityType,
                    subtitle: subtitle,
                    subtitleTint: .secondary,
                    detail: "",
                    secondLineText: "—",
                    statusTitle: "Training",
                    statusTint: .blue,
                    exerciseDetails: [],
                    emptyExerciseMessage: "Suggested exercises are generated when you start a Track session."
                )
                results.append(entry)
            }
        }

        return results
    }

    private func plannedActivitiesFutureEntries(completedDays: Set<Date>) -> [ActivityEntry] {
        store.plannedActivities
            .filter { calendar.startOfDay(for: $0.date) > startOfToday }
            .filter { !completedDays.contains(calendar.startOfDay(for: $0.date)) }
            .map { planned in
                ActivityEntry(
                    id: planned.id.uuidString,
                    kind: .planned,
                    workoutID: nil,
                    date: planned.date,
                    title: planned.activityType,
                    subtitle: "",
                    subtitleTint: .secondary,
                    detail: "",
                    secondLineText: "—",
                    statusTitle: "Planned",
                    statusTint: .blue,
                    exerciseDetails: [],
                    emptyExerciseMessage: "This activity will appear here on the day it happens."
                )
            }
    }

    private var upcomingWorkoutDayGroups: [UpcomingWorkoutDayGroup] {
        let groupedEntries = Dictionary(grouping: futureEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return groupedEntries
            .map { day, entries in
                let sortedEntries = entries.sorted { lhs, rhs in
                    if isTraditionalStrengthActivityType(lhs.title) != isTraditionalStrengthActivityType(rhs.title) {
                        return isTraditionalStrengthActivityType(lhs.title)
                    }

                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return UpcomingWorkoutDayGroup(
                    date: day,
                    strengthEntries: sortedEntries.filter { isTraditionalStrengthActivityType($0.title) },
                    otherEntries: sortedEntries.filter { !isTraditionalStrengthActivityType($0.title) }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var todayEntries: [ActivityEntry] {
        let completedDays = Set(strengthWorkouts.map { calendar.startOfDay(for: $0.date) })
        return store.scheduledRoutineActivities(for: .now)
            .filter { !completedDays.contains(calendar.startOfDay(for: $0.date)) }
            .filter { scheduledActivity in
                !hasImportedWorkout(on: scheduledActivity.date, activityType: scheduledActivity.routineActivity.activityType)
            }
            .map { scheduledActivity in
                return ActivityEntry(
                    id: "today-\(scheduledActivity.id)",
                    kind: .planned,
                    workoutID: nil,
                    date: scheduledActivity.date,
                    title: scheduledActivity.routineActivity.activityType,
                    subtitle: scheduledActivity.focusSummary,
                    subtitleTint: .secondary,
                    detail: "",
                    secondLineText: "—",
                    statusTitle: "",
                    statusTint: .blue,
                    exerciseDetails: [],
                    emptyExerciseMessage: "Suggested exercises are generated when you start a Track session."
                )
            }
    }

    private var pastWorkouts: [CompletedWorkoutSummary] {
        importedWorkouts.filter { calendar.startOfDay(for: $0.date) < startOfToday }
    }

    private var todayWorkoutDayGroup: PastWorkoutDayGroup? {
        let todaysWorkouts = importedWorkouts.filter { calendar.isDate($0.date, inSameDayAs: .now) }
        guard !todaysWorkouts.isEmpty else { return nil }

        let sortedWorkouts = todaysWorkouts.sorted { lhs, rhs in
            if isStrengthOrCoreWorkout(lhs) != isStrengthOrCoreWorkout(rhs) {
                return isStrengthOrCoreWorkout(lhs)
            }

            return lhs.date > rhs.date
        }

        return PastWorkoutDayGroup(
            date: startOfToday,
            strengthWorkouts: sortedWorkouts.filter(isStrengthOrCoreWorkout),
            otherWorkouts: sortedWorkouts.filter { !isStrengthOrCoreWorkout($0) }
        )
    }

    private var pastWorkoutDayGroups: [PastWorkoutDayGroup] {
        let groupedWorkouts = Dictionary(grouping: pastWorkouts) { workout in
            calendar.startOfDay(for: workout.date)
        }

        return groupedWorkouts
            .map { day, workouts in
                let sortedWorkouts = workouts.sorted { lhs, rhs in
                    if isStrengthOrCoreWorkout(lhs) != isStrengthOrCoreWorkout(rhs) {
                        return isStrengthOrCoreWorkout(lhs)
                    }

                    return lhs.date > rhs.date
                }

                return PastWorkoutDayGroup(
                    date: day,
                    strengthWorkouts: sortedWorkouts.filter(isStrengthOrCoreWorkout),
                    otherWorkouts: sortedWorkouts.filter { !isStrengthOrCoreWorkout($0) }
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// Today: planned entries first, then completed (strength then other) — one card per item.
    private var allTodayActivityEntries: [ActivityEntry] {
        let planned = todayEntries
        let completed: [ActivityEntry] = (todayWorkoutDayGroup.map { group in
            group.strengthWorkouts.map { activityEntry(for: $0) } + group.otherWorkouts.map { activityEntry(for: $0) }
        }) ?? []
        return planned + completed
    }

    /// Past: all completed workouts as flat list, most recent first.
    private var allPastActivityEntries: [ActivityEntry] {
        pastWorkoutDayGroups.flatMap { group in
            group.strengthWorkouts.map { activityEntry(for: $0) } + group.otherWorkouts.map { activityEntry(for: $0) }
        }
    }

    private var strengthWorkouts: [CompletedWorkoutSummary] {
        importedWorkouts.filter(isStrengthOrCoreWorkout)
    }

    private var importedWorkouts: [CompletedWorkoutSummary] {
        store.history.filter { workout in
            !workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func isTraditionalStrengthWorkout(_ workout: CompletedWorkoutSummary) -> Bool {
        isTraditionalStrengthActivityType(workout.activityType)
    }

    /// True for Traditional Strength Training or Core Training (grouped together in Today/Past, tappable for exercises).
    private func isStrengthOrCoreWorkout(_ workout: CompletedWorkoutSummary) -> Bool {
        let t = workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "traditional strength training" || t == "core training"
    }

    private func isStrengthOrCoreActivityTitle(_ title: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "traditional strength training" || t == "core training"
    }

    private func isTraditionalStrengthActivityType(_ activityType: String) -> Bool {
        activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "traditional strength training"
    }

    private func hasImportedWorkout(on date: Date, activityType: String) -> Bool {
        let normalizedActivityType = activityType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedActivityType.isEmpty else { return false }

        return importedWorkouts.contains { workout in
            calendar.isDate(workout.date, inSameDayAs: date) &&
            workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedActivityType) == .orderedSame
        }
    }

    private func activityEntry(for workout: CompletedWorkoutSummary) -> ActivityEntry {
        let isStrengthOrCore = isStrengthOrCoreWorkout(workout)
        let exerciseCount = workout.exerciseDetails.count
        let listTitle: String
        let statusTitle: String
        if isStrengthOrCore {
            listTitle = workout.activityType
            statusTitle = exerciseCount > 0 ? "\(exerciseCount) Completed" : ""
        } else {
            listTitle = workout.activityType
            statusTitle = "Completed"
        }
        let durationText = "\(workout.durationMinutes) min"
        let completedSuffix = isStrengthOrCore && exerciseCount > 0 ? " • \(exerciseCount) completed" : ""
        return ActivityEntry(
            id: workout.id.uuidString,
            kind: .completed,
            workoutID: workout.id,
            date: workout.date,
            title: listTitle,
            subtitle: completedWorkoutSubtitle(for: workout),
            subtitleTint: workout.exerciseDetails.isEmpty ? Color.secondary : Color.green,
            detail: completedWorkoutDetail(for: workout),
            secondLineText: durationText + completedSuffix,
            statusTitle: statusTitle,
            statusTint: Color.green,
            exerciseDetails: workout.exerciseDetails.map(Self.makeExerciseDetail),
            emptyExerciseMessage: "Exercise details were not recorded for this imported Apple Health workout."
        )
    }

    private func completedWorkoutSubtitle(for workout: CompletedWorkoutSummary) -> String {
        let exerciseCount = workout.exerciseDetails.count
        let exerciseCountText = exerciseCount == 1 ? "1 exercise completed" : "\(exerciseCount) exercises completed"
        let summary = workout.summary.caseInsensitiveCompare(workout.activityType) == .orderedSame ? "Completed workout" : workout.summary

        if exerciseCount == 0 {
            return summary
        }

        if summary == "Completed workout" {
            return exerciseCountText
        }

        return "\(summary) • \(exerciseCountText)"
    }

    private func completedWorkoutDetail(for workout: CompletedWorkoutSummary) -> String {
        let trimmedLocation = workout.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLocation.isEmpty || trimmedLocation.caseInsensitiveCompare("Apple Health") == .orderedSame {
            return "\(workout.durationMinutes) min"
        }

        return "\(workout.durationMinutes) min at \(trimmedLocation)"
    }

    private func weekdayDateText(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "TODAY"
        }

        if calendar.isDateInTomorrow(date) {
            return "TOMORROW"
        }

        if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        }

        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()).uppercased()
    }

    /// Date label for session-style card bottom right: "Today", "Tomorrow", "Yesterday", or "Wed, Mar 11, 2026".
    private func sessionDateLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private var calendar: Calendar {
        .current
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: .now)
    }

    private var pastSessionsEmptyMessage: String {
        switch store.healthSyncState {
        case .notConnected:
            return "Connect Apple Health in Settings to import your past workouts."
        case .connected, .refreshing, .refreshed:
            return "No workouts were found in Apple Health yet."
        case .failed(let message):
            return "Apple Health import failed: \(message)"
        }
    }

    static func makeExerciseDetail(from exercise: CompletedExerciseDetail) -> ActivityExerciseDetail {
        let setRepDetail: String
        switch (exercise.sets, exercise.reps) {
        case let (.some(sets), .some(reps)):
            setRepDetail = "\(sets) sets x \(reps) reps"
        case let (.some(sets), nil):
            setRepDetail = "\(sets) sets"
        case let (nil, .some(reps)):
            setRepDetail = "\(reps) reps"
        case (nil, nil):
            setRepDetail = ""
        }

        return ActivityExerciseDetail(
            completedExerciseID: exercise.id,
            title: exercise.title,
            subtitle: setRepDetail.isEmpty ? "Logged exercise" : setRepDetail,
            detail: exercise.bodyPart?.title ?? "",
            note: exercise.notes
        )
    }
}

private struct TrackScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthSyncController: HealthSyncController
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes = 20
    @State private var setupActivityType: String?
    @State private var setupSelectedBodyParts: Set<ExerciseBodyArea> = []
    @State private var isShowingSetupSheet = false
    @State private var isShowingOtherExerciseSheet = false
    @State private var isShowingFinishSheet = false
    @State private var isShowingDiscardAlert = false
    @State private var finishMessage = ""
    @State private var isShowingFinishMessage = false
    @State private var isShowingExerciseTimer = false
    @State private var activeExerciseID: UUID?
    @State private var activeExerciseTitle: String = ""

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                if let trackedSession {
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(trackedSession.title)
                                .font(.headline)
                            Text("\(trackedSession.plannedDurationMinutes) min at \(trackedSession.locationName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(store.completedTrackedExerciseCount) of \(trackedSession.exercises.count) exercises checked")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)

                            Text(formattedElapsedTime(from: store.totalCompletedTrackedDuration))
                                .font(.system(.title, design: .monospaced).weight(.bold))
                                .padding(.top, 4)
                            Text("Workout time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SectionTitle(title: "Suggested Exercises")
                    if trackedSession.exercises.isEmpty {
                        AppCard {
                            EmptyCardMessage(message: "No suggested exercises match this location yet.")
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(trackedSession.exercises) { exercise in
                                TrackExerciseRow(exercise: exercise) {
                                    activeExerciseID = exercise.id
                                    activeExerciseTitle = exercise.plannedExercise.title
                                    isShowingExerciseTimer = true
                                }
                            }

                            Button {
                                isShowingOtherExerciseSheet = true
                            } label: {
                                AppCard {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "plus.circle")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Other")
                                                .font(.headline)
                                            Text("Add another exercise from your catalog.")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 10) {
                        WideActionButton(title: "Finish Workout", tint: .green) {
                            isShowingFinishSheet = true
                        }

                        WideActionButton(title: "Cancel", tint: .red) {
                            isShowingDiscardAlert = true
                        }
                    }
                } else {
                    SectionTitle(title: "Track")
                    VStack(spacing: 12) {
                        Button {
                            prepareSetup(for: "Traditional Strength Training")
                        } label: {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.blue)
                                .overlay(
                                    HStack {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.title2)
                                        Text("Strength Training")
                                            .font(.body.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                )
                                .frame(height: 56)
                        }
                        .buttonStyle(.plain)

                        Button {
                            prepareSetup(for: "Core Training")
                        } label: {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.blue)
                                .overlay(
                                    HStack {
                                        Image(systemName: "figure.core.training")
                                            .font(.title2)
                                        Text("Core Training")
                                            .font(.body.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                )
                                .frame(height: 56)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !store.pendingTrackedWorkouts.isEmpty {
                    SectionTitle(title: "Waiting For Apple Health")
                    VStack(spacing: 10) {
                        ForEach(store.pendingTrackedWorkouts.prefix(3)) { pendingWorkout in
                            AppCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(pendingWorkout.summary)
                                        .font(.headline)
                                    Text("\(pendingWorkout.durationMinutes) min at \(pendingWorkout.locationName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(pendingWorkout.exerciseDetails.count) checked exercises will attach when the matching Apple Health workout appears.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedLocationID = selectedLocationID ?? store.locations.first?.id
                selectedDurationMinutes = selectedDurationMinutes > 0 ? selectedDurationMinutes : 20
            }
            .sheet(isPresented: $isShowingFinishSheet) {
                TrackFinishSheet(
                    checkedExerciseCount: store.completedTrackedExerciseCount,
                    onConfirm: {
                        guard let session = store.trackedWorkoutSession else { return }
                        let completedAt = Date()
                        let completedCount = store.completedTrackedExerciseCount

                        if completedCount > 0 {
                            let pending = store.buildPendingTrackedWorkoutMerge(completedAt: completedAt)
                            if let pending = pending {
                                store.addPendingTrackedWorkout(pending)
                            }
                            finishMessage = "Completed \(completedCount) exercises. Your workout will appear after it syncs from Apple Health."
                            Task {
                                if let pending = pending {
                                    await healthSyncController.logWorkoutFromTrackSession(pending, using: store)
                                } else {
                                    await healthSyncController.logWorkoutFromTrackedSession(
                                        session,
                                        completedAt: completedAt,
                                        using: store
                                    )
                                }
                            }
                        } else {
                            finishMessage = "No exercises completed. Session discarded."
                        }

                        store.discardTrackedWorkoutSession()
                        store.persist()
                        isShowingFinishSheet = false
                        isShowingFinishMessage = true
                    },
                    onCancel: {
                        isShowingFinishSheet = false
                    }
                )
            }
            .sheet(isPresented: $isShowingOtherExerciseSheet) {
                TrackOtherExercisePicker(
                    exercises: store.exerciseLibrary,
                    onSelect: { exercise in
                        store.addTrackedExercise(exercise)
                        store.persist()
                        isShowingOtherExerciseSheet = false
                    }
                )
            }
            .alert("Track Session Saved", isPresented: $isShowingFinishMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(finishMessage)
            }
            .alert("Cancel This Session?", isPresented: $isShowingDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Cancel Session", role: .destructive) {
                    store.discardTrackedWorkoutSession()
                    store.persist()
                }
            } message: {
                Text("This will discard the current Track checklist without saving it.")
            }
            .sheet(isPresented: $isShowingExerciseTimer) {
                TrackExerciseTimerView(
                    title: activeExerciseTitle,
                    instructions: store.exerciseLibrary.first { lib in
                        lib.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            .caseInsensitiveCompare(activeExerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                    }?.instructions ?? "",
                    onComplete: { elapsed in
                        if let id = activeExerciseID {
                            store.completeTrackedExercise(id: id, durationSeconds: elapsed)
                            store.persist()
                        }
                        isShowingExerciseTimer = false
                    },
                    onCancel: {
                        isShowingExerciseTimer = false
                    }
                )
            }
            .sheet(isPresented: $isShowingSetupSheet) {
                Group {
                    if let activityType = setupActivityType {
                        TrackSetupSheet(
                            activityType: activityType,
                            selectedBodyParts: $setupSelectedBodyParts,
                            selectedLocationID: $selectedLocationID,
                            selectedDurationMinutes: $selectedDurationMinutes,
                            locations: store.locations,
                            allowedBodyParts: allowedTrainingBodyAreas(for: activityType),
                            onCancel: {
                                isShowingSetupSheet = false
                            },
                            onStart: {
                                let focusAreas = Array(setupSelectedBodyParts)
                                guard !focusAreas.isEmpty else { return }

                                _ = store.startTrackedWorkout(
                                    activityType: activityType,
                                    focusAreas: focusAreas,
                                    targetDate: .now,
                                    locationID: selectedLocationID,
                                    durationMinutes: selectedDurationMinutes
                                )
                                store.persist()
                                isShowingSetupSheet = false
                            }
                        )
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }

    private var trackedSession: TrackedWorkoutSession? {
        store.trackedWorkoutSession
    }

    private func prepareSetup(for activityType: String) {
        setupActivityType = activityType

        let allowedAreas = allowedTrainingBodyAreas(for: activityType)
        let today = store.weekday(for: .now)
        if let template = trainingTemplate(for: activityType) {
            let scheduledAreas = template.bodyPartSchedules
                .filter { $0.weekdays.contains(today) }
                .map(\.bodyPart)
            if !scheduledAreas.isEmpty {
                setupSelectedBodyParts = Set(scheduledAreas.filter { allowedAreas.contains($0) })
            } else {
                setupSelectedBodyParts = Set(allowedAreas)
            }
        } else {
            setupSelectedBodyParts = Set(allowedAreas)
        }

        selectedLocationID = selectedLocationID ?? store.defaultLocation?.id ?? store.locations.first?.id
        selectedDurationMinutes = max(selectedDurationMinutes, 5)
        isShowingSetupSheet = true
    }

    private func trainingTemplate(for activityType: String) -> RoutineActivity? {
        store.routineActivities.first {
            $0.isTrainingTemplate &&
            $0.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activityType) == .orderedSame
        }
    }

    private func allowedTrainingBodyAreas(for activityType: String) -> [ExerciseBodyArea] {
        let normalized = activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "core training" {
            return [.glutes, .abs]
        }

        return ExerciseBodyArea.allCases.filter { area in
            area != .glutes && area != .abs
        }
    }

    private func formattedElapsedTime(from interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval), 0)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

}

private struct TrackSetupSheet: View {
    let activityType: String
    @Binding var selectedBodyParts: Set<ExerciseBodyArea>
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDurationMinutes: Int
    let locations: [LocationItem]
    let allowedBodyParts: [ExerciseBodyArea]
    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                VStack(alignment: .leading, spacing: 16) {
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activityType)
                                .font(.headline)
                            Text("Choose which body parts to emphasize for this session, then pick where and how long you want to train.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SectionTitle(title: "Target Body Parts")
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(allowedBodyParts) { area in
                                Toggle(
                                    area.title,
                                    isOn: Binding(
                                        get: { selectedBodyParts.contains(area) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedBodyParts.insert(area)
                                            } else {
                                                selectedBodyParts.remove(area)
                                            }
                                        }
                                    )
                                )
                            }
                        }
                    }

                    SectionTitle(title: "Location & Duration")
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Location", selection: $selectedLocationID) {
                                ForEach(locations) { location in
                                    Text(location.name).tag(Optional(location.id))
                                }
                            }

                            Picker("Duration", selection: $selectedDurationMinutes) {
                                ForEach([10, 15, 20, 30, 45], id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        WideActionButton(title: "Cancel", tint: .gray, action: onCancel)
                        WideActionButton(title: "Start Workout", tint: .blue) {
                            onStart()
                        }
                        .disabled(selectedBodyParts.isEmpty)
                    }
                }
            }
            .navigationTitle("Track Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TrackExerciseTimerView: View {
    let title: String
    let instructions: String
    let onComplete: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.headline)

                        if !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(instructions)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Elapsed Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TimelineView(.periodic(from: startDate, by: 0.1)) { context in
                            let elapsed = context.date.timeIntervalSince(startDate)
                            Text(formattedElapsedTime(from: elapsed))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        HStack(spacing: 12) {
                            WideActionButton(title: "Cancel", tint: .gray) {
                                onCancel()
                            }
                            WideActionButton(title: "Complete", tint: .green) {
                                let elapsed = Date().timeIntervalSince(startDate)
                                onComplete(elapsed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Track Exercise")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedElapsedTime(from interval: TimeInterval) -> String {
        let totalHundredths = max(Int((interval * 100).rounded()), 0)
        let hundredths = totalHundredths % 100
        let totalSeconds = totalHundredths / 100
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        }
    }
}

private struct TrackOtherExercisePicker: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [ExerciseLibraryItem]
    let onSelect: (ExerciseLibraryItem) -> Void

    @State private var selectedBodyPart: ExerciseBodyArea?

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose another exercise from your catalog and add it to this Track session.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Body Part", selection: $selectedBodyPart) {
                            Text("All").tag(ExerciseBodyArea?.none)
                            ForEach(ExerciseBodyArea.allCases) { area in
                                Text(area.title).tag(Optional(area))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            AppCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(exercise.name)
                                        .font(.headline)
                                        .multilineTextAlignment(.leading)
                                    Text(exercise.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Other Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredExercises: [ExerciseLibraryItem] {
        guard let selectedBodyPart else { return exercises }
        return exercises.filter { $0.primaryMuscles.contains(selectedBodyPart) }
    }
}

private struct TrackSelectedRoutinesStartSheet: View {
    let routineActivities: [RoutineActivity]
    @Binding var routineWeights: [UUID: Int]
    let recommendedRoutineWeights: [UUID: Int]
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDurationMinutes: Int
    let locations: [LocationItem]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confirm Workout Details")
                            .font(.headline)
                        Text(routineSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Double-check the location and duration before generating your suggested workout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if routineActivities.count > 1 {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Plan Mix")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button("Use Recommended") {
                                        routineWeights = recommendedRoutineWeights
                                    }
                                    .font(.footnote.weight(.medium))
                                }

                                Text("Recommended values balance what you have already trained this week with your current focus.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                RoutineMixSlider(
                                    routineTitles: routineActivities.map(\.title),
                                    weights: Binding(
                                        get: { resolvedRoutineWeights },
                                        set: { newValue in
                                            routineWeights = Dictionary(
                                                uniqueKeysWithValues: zip(routineActivities.map(\.id), newValue)
                                            )
                                        }
                                    )
                                )

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(routineActivities.enumerated()), id: \.element.id) { index, routineActivity in
                                        HStack {
                                            Circle()
                                                .fill(mixColor(for: index))
                                                .frame(width: 10, height: 10)
                                            Text(routineActivity.title)
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text("\(resolvedRoutineWeights[safe: index] ?? 0)%")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Location")
                                .font(.subheadline.weight(.semibold))

                            Picker("Location", selection: $selectedLocationID) {
                                ForEach(locations) { location in
                                    Text(location.name).tag(Optional(location.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Duration")
                                .font(.subheadline.weight(.semibold))

                            Picker("Planned Duration", selection: $selectedDurationMinutes) {
                                ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                                    Text("\(duration) min").tag(duration)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                WideActionButton(title: "Start Workout", tint: .blue, action: onConfirm)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var navigationTitle: String {
        if routineActivities.count == 1 {
            return routineActivities.first?.title ?? "Plan"
        }

        return "\(routineActivities.count) Plans"
    }

    private var routineSummary: String {
        let uniqueFocusAreas = Array(Set(routineActivities.flatMap(\.focusAreas)))
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map(\.title)

        if uniqueFocusAreas.isEmpty {
            return routineActivities.map(\.title).joined(separator: ", ")
        }

        return uniqueFocusAreas.joined(separator: ", ")
    }

    private var resolvedRoutineWeights: [Int] {
        normalizedWeights(
            routineActivities.map { routineActivity in
                routineWeights[routineActivity.id] ?? recommendedRoutineWeights[routineActivity.id] ?? 0
            }
        )
    }

    private func normalizedWeights(_ inputWeights: [Int]) -> [Int] {
        guard !inputWeights.isEmpty else { return [] }

        let sanitizedWeights = inputWeights.map { max($0, 0) }
        let total = sanitizedWeights.reduce(0, +)
        let workingWeights = total == 0 ? Array(repeating: 1, count: sanitizedWeights.count) : sanitizedWeights
        let denominator = max(workingWeights.reduce(0, +), 1)

        var baseAllocations: [Int] = []
        var remainders: [(index: Int, remainder: Double)] = []
        var used = 0

        for (index, weight) in workingWeights.enumerated() {
            let exact = (Double(weight) / Double(denominator)) * 100
            let base = Int(exact.rounded(.down))
            baseAllocations.append(base)
            used += base
            remainders.append((index, exact - Double(base)))
        }

        let remaining = max(100 - used, 0)
        for item in remainders.sorted(by: { lhs, rhs in
            if lhs.remainder != rhs.remainder {
                return lhs.remainder > rhs.remainder
            }
            return lhs.index < rhs.index
        }).prefix(remaining) {
            baseAllocations[item.index] += 1
        }

        return baseAllocations
    }

    private func mixColor(for index: Int) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple]
        return palette[index % palette.count]
    }
}

private struct RoutineMixSlider: View {
    let routineTitles: [String]
    @Binding var weights: [Int]

    private let step: Int = 5
    private let trackHeight: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let boundaries = cumulativeBoundaries(for: normalizedWeights)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: trackHeight)

                HStack(spacing: 0) {
                    ForEach(Array(normalizedWeights.enumerated()), id: \.offset) { index, weight in
                        Rectangle()
                            .fill(mixColor(for: index))
                            .frame(width: max(totalWidth * CGFloat(weight) / 100, weight == 0 ? 0 : 6))
                    }
                }
                .clipShape(Capsule())
                .frame(height: trackHeight)

                ForEach(Array(boundaries.enumerated()), id: \.offset) { index, boundary in
                    let xPosition = min(max(totalWidth * boundary, 0), totalWidth)

                    ZStack {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 28, height: 28)

                        Image(systemName: "line.3.horizontal")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                    .position(x: xPosition, y: trackHeight / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let rawFraction = min(max(value.location.x / totalWidth, 0), 1)
                                let steppedFraction = stepped(rawFraction)
                                updateBoundary(at: index, to: steppedFraction)
                            }
                    )
                }
            }
        }
        .frame(height: 28)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                ForEach(0..<21, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1, height: 6)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 1)
            .offset(y: 10)
        }
    }

    private var normalizedWeights: [Int] {
        let sanitizedWeights = weights.map { max($0, 0) }
        let total = sanitizedWeights.reduce(0, +)
        let fallback = sanitizedWeights.isEmpty ? [] : Array(repeating: 100 / sanitizedWeights.count, count: sanitizedWeights.count)

        if total == 100 {
            return sanitizedWeights
        }

        if total == 0 {
            var adjustedFallback = fallback
            if !adjustedFallback.isEmpty {
                adjustedFallback[0] += 100 - adjustedFallback.reduce(0, +)
            }
            return adjustedFallback
        }

        var scaled = sanitizedWeights.map { Int((Double($0) / Double(total) * 100).rounded(.down)) }
        let remainder = 100 - scaled.reduce(0, +)
        if remainder > 0, !scaled.isEmpty {
            scaled[0] += remainder
        }
        return scaled
    }

    private func cumulativeBoundaries(for weights: [Int]) -> [CGFloat] {
        guard weights.count > 1 else { return [] }

        var runningTotal = 0
        return weights.dropLast().map { weight in
            runningTotal += weight
            return CGFloat(runningTotal) / 100
        }
    }

    private func stepped(_ fraction: CGFloat) -> CGFloat {
        let rawPercentage = Double(fraction * 100)
        let steppedPercentage = (rawPercentage / Double(step)).rounded() * Double(step)
        return CGFloat(steppedPercentage / 100)
    }

    private func updateBoundary(at index: Int, to newBoundary: CGFloat) {
        var boundaries = cumulativeBoundaries(for: normalizedWeights)
        guard boundaries.indices.contains(index) else { return }

        let lowerBound = index == 0 ? CGFloat(0) : boundaries[index - 1]
        let upperBound = index == boundaries.count - 1 ? CGFloat(1) : boundaries[index + 1]
        boundaries[index] = min(max(newBoundary, lowerBound), upperBound)

        var rebuiltWeights: [Int] = []
        var previousBoundary = CGFloat(0)
        for boundary in boundaries {
            rebuiltWeights.append(Int(((boundary - previousBoundary) * 100).rounded()))
            previousBoundary = boundary
        }
        rebuiltWeights.append(max(100 - rebuiltWeights.reduce(0, +), 0))

        if rebuiltWeights.count == weights.count {
            weights = rebuiltWeights
        }
    }

    private func mixColor(for index: Int) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple]
        return palette[index % palette.count]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private enum ActivityEntryKind {
    case planned
    case completed
}

private struct ActivityEntry: Identifiable {
    let id: String
    let kind: ActivityEntryKind
    let workoutID: UUID?
    let date: Date
    let title: String
    let subtitle: String
    let subtitleTint: Color
    let detail: String
    /// Shown on second line of session-style card: duration and optional "• N completed".
    let secondLineText: String
    let statusTitle: String
    let statusTint: Color
    let exerciseDetails: [ActivityExerciseDetail]
    let emptyExerciseMessage: String
}

private struct ActivityExerciseDetail: Identifiable {
    let id = UUID()
    let completedExerciseID: UUID?
    let title: String
    let subtitle: String
    let detail: String
    let note: String
}

private struct ActivityEntryCard: View {
    let entry: ActivityEntry

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(entry.title)
                            .font(.headline)
                        Spacer()
                        Text(entry.statusTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.statusTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.statusTint.opacity(0.12), in: Capsule())
                    }

                    Text(entry.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(entry.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .padding(.horizontal, -2)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(entry.statusTint.opacity(0.28), lineWidth: 1)
                }
            }
        }
    }

}

/// SF Symbol name for activity type. Aligned with HealthKit / Fitness activity names (see e.g. https://philip-trauner.me/blog/post/fitness-ui-icons). Uses SF Symbols as the public alternative to FitnessUI asset names.
private enum ActivityIcon {
    static func symbol(for activityType: String) -> String {
        let t = activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch t {
        // Strength & core
        case "traditional strength training": return "figure.strengthtraining.traditional"
        case "core training": return "figure.core.training"
        case "functional strength training": return "figure.strengthtraining.functional"
        case "barre": return "figure.barre"
        case "pilates": return "figure.pilates"
        case "flexibility": return "figure.flexibility"
        case "cooldown": return "figure.cooldown"
        // Cardio & outdoor
        case "pool swim", "swimming": return "figure.pool.swim"
        case "running", "run": return "figure.run"
        case "cycling", "bike": return "figure.outdoor.cycle"
        case "walking", "walk": return "figure.walk"
        case "elliptical": return "figure.elliptical"
        case "rowing", "rower": return "figure.rower"
        case "high intensity interval training", "hiit": return "figure.highintensity.intervaltraining"
        case "mixed cardio", "mixed metabolic cardio training": return "figure.mixed.cardio"
        // Water & snow (FitnessUI: surfing, swimopen, outdoorcycle, outdoorrun, etc.)
        case "surfing sports", "surfing": return "figure.surfing"
        case "downhill skiing", "cross country skiing", "snow sports", "skiing": return "figure.skiing.downhill"
        case "snowboarding": return "figure.snowboarding"
        case "water fitness", "water sports", "water polo": return "figure.pool.swim"
        case "sailing", "paddle sports": return "figure.surfing"
        // Mind & body
        case "yoga": return "figure.yoga"
        case "dance", "cardio dance", "social dance", "dance inspired training": return "figure.dance"
        case "tai chi", "mind and body": return "figure.yoga"
        case "preparation and recovery", "prep and recovery": return "figure.cooldown"
        // Sports
        case "climbing": return "figure.climbing"
        case "golf": return "figure.golf"
        case "tennis": return "figure.tennis"
        case "table tennis": return "figure.tennis"
        case "basketball": return "figure.basketball"
        case "soccer": return "figure.soccer"
        case "baseball": return "figure.baseball"
        case "volleyball": return "figure.volleyball"
        case "boxing": return "figure.boxing"
        case "martial arts": return "figure.martial.arts"
        case "kickboxing": return "figure.kickboxing"
        case "wrestling": return "figure.wrestling"
        case "hiking": return "figure.hiking"
        case "stair climbing", "stairs", "step training": return "figure.stairs"
        case "cross training": return "figure.mixed.cardio"
        case "hand cycling": return "figure.outdoor.cycle"
        case "jump rope": return "figure.highintensity.intervaltraining"
        case "swim bike run", "transition": return "figure.mixed.cardio"
        case "underwater diving": return "figure.pool.swim"
        // Other sports (use SF Symbols that are widely available; fallback for rare ones)
        case "american football", "australian football", "rugby": return "figure.football"
        case "badminton", "pickleball", "racquetball", "squash": return "figure.tennis"
        case "fishing": return "figure.fishing"
        case "fitness gaming", "play": return "figure.play"
        case "hockey": return "figure.hockey"
        case "track and field": return "figure.run"
        case "archery", "bowling", "curling", "disc sports", "equestrian sports", "fencing",
             "gymnastics", "handball", "hunting", "lacrosse", "skating sports", "softball",
             "wheelchair walk pace", "wheelchair run pace", "other": return "figure.mixed.cardio"
        default: return "figure.mixed.cardio"
        }
    }
}

/// Session-style card: title on line 1; line 2 left = duration (Today/Past) or Training/Planned/Recurring (Upcoming), right = date. Optional subtle chevron when tappable.
private struct SessionStyleActivityCard: View {
    let entry: ActivityEntry
    let dateLabel: String
    var showChevron: Bool = false
    var compactVerticalPadding: Bool = false

    private var secondLineText: String {
        if entry.kind == .planned, !entry.statusTitle.isEmpty {
            return entry.statusTitle
        }
        return entry.secondLineText
    }

    private var secondLineColor: Color {
        if entry.kind == .completed, secondLineText != "—" {
            return Color.green
        }
        return Color.secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ActivityIcon.symbol(for: entry.title))
                .font(.title2)
                .foregroundStyle(entry.kind == .planned ? Color.blue : Color.green)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack {
                    if entry.kind == .planned, !entry.statusTitle.isEmpty {
                        Text(entry.statusTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    } else {
                        Text(secondLineText)
                            .font(.subheadline)
                            .foregroundStyle(secondLineColor)
                    }
                    Spacer(minLength: 0)
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compactVerticalPadding ? 6 : 10)
    }
}

private struct TrackExerciseRow: View {
    let exercise: TrackedExerciseState
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            AppCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(exercise.isCompleted ? Color.green : Color.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.plannedExercise.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Text(exercise.plannedExercise.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TrackFinishSheet: View {
    let checkedExerciseCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Finish Workout")
                            .font(.headline)
                        Text("Save this Track session and wait for the matching Apple Health workout to arrive before it appears in history.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(checkedSummary)
                            .font(.subheadline.weight(.medium))
                    }
                }

                WideActionButton(title: "Confirm Finish", tint: .green, action: onConfirm)
            }
            .navigationTitle("Finish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var checkedSummary: String {
        checkedExerciseCount == 1
            ? "1 exercise checked"
            : "\(checkedExerciseCount) exercises checked"
    }
}

private struct StrengthWorkoutSummaryRow: View {
    let entry: ActivityEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title)
                        .font(.headline)

                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    if !entry.statusTitle.isEmpty {
                        Text(entry.statusTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.statusTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.statusTint.opacity(0.12), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .padding(.horizontal, -2)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(entry.statusTitle.isEmpty ? Color.clear : entry.statusTint.opacity(0.28), lineWidth: 1)
        )
    }

    private var summaryLine: String {
        let trimmedSubtitle = entry.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = entry.detail.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSubtitle.caseInsensitiveCompare("Completed workout") == .orderedSame,
           trimmedDetail.hasSuffix("min")
        {
            return "Completed \(trimmedDetail) workout"
        }

        if trimmedDetail.isEmpty {
            return trimmedSubtitle
        }

        if trimmedSubtitle.isEmpty {
            return trimmedDetail
        }

        return "\(trimmedSubtitle) • \(trimmedDetail)"
    }
}

private struct ReadOnlyWorkoutRow: View {
    let workout: CompletedWorkoutSummary

    var body: some View {
        Text(workout.activityType)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 2)
    }
}

private struct PlannedReadOnlyActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        Text(rowText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 2)
    }

    private var rowText: String {
        "\(entry.title) • \(entry.detail)"
    }
}

private struct UpcomingActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(entry.title)
                .font(.footnote)
            Spacer(minLength: 8)
            if !entry.statusTitle.isEmpty {
                Text(entry.statusTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.statusTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(entry.statusTint.opacity(0.12), in: Capsule())
            }
        }
    }
}

/// Line-item row for completed workouts in Today/Past (matches Upcoming style: title, label, chevron).
private struct CompletedActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(entry.title)
                .font(.footnote)
            Spacer(minLength: 8)
            if !entry.statusTitle.isEmpty {
                Text(entry.statusTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.statusTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(entry.statusTint.opacity(0.12), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct UpcomingWorkoutDayGroup: Identifiable {
    let date: Date
    let strengthEntries: [ActivityEntry]
    let otherEntries: [ActivityEntry]

    var id: Date { date }
}

private struct PastWorkoutDayGroup: Identifiable {
    let date: Date
    let strengthWorkouts: [CompletedWorkoutSummary]
    let otherWorkouts: [CompletedWorkoutSummary]

    var id: Date { date }
}

private struct ActivityEntryDetailScreen: View {
    @EnvironmentObject private var store: AppStore
    let entry: ActivityEntry

    @State private var editingExercise: CompletedExerciseDetail?
    @State private var isAddingExercise = false
    @State private var isImportingPreviousActivity = false

    private var completedWorkout: CompletedWorkoutSummary? {
        guard let workoutID = entry.workoutID else { return nil }
        return store.history.first(where: { $0.id == workoutID })
    }

    private var displayedExerciseDetails: [ActivityExerciseDetail] {
        if let completedWorkout {
            return completedWorkout.exerciseDetails.map(ActivityScreen.makeExerciseDetail)
        }

        return entry.exerciseDetails
    }

    private var previousLoggedWorkouts: [CompletedWorkoutSummary] {
        guard let completedWorkout else { return [] }

        return store.history
            .filter {
                $0.id != completedWorkout.id &&
                !$0.exerciseDetails.isEmpty
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScreenScrollContainer {
            AppCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !entry.statusTitle.isEmpty {
                            Text(entry.statusTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(entry.statusTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(entry.statusTint.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(entry.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(entry.subtitleTint)

                    Text(entry.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                SectionTitle(title: entry.kind == .completed ? "Exercises Completed" : "Exercises Planned")
                Spacer()
                if entry.kind == .completed {
                    Button {
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            if displayedExerciseDetails.isEmpty {
                AppCard {
                    EmptyCardMessage(message: entry.emptyExerciseMessage)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedExerciseDetails) { exercise in
                        AppCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(exercise.title)
                                            .font(.headline)

                                        Text(exercise.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        if !exercise.detail.isEmpty {
                                            Text(exercise.detail)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        if !exercise.note.isEmpty {
                                            Text(exercise.note)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if entry.kind == .completed, let exerciseID = exercise.completedExerciseID {
                                        HStack(spacing: 8) {
                                            SmallIconButton(systemImage: "pencil") {
                                                editingExercise = completedWorkout?.exerciseDetails.first(where: { $0.id == exerciseID })
                                            }

                                            SmallIconButton(systemImage: "trash", tint: .red) {
                                                guard var workout = completedWorkout else { return }
                                                workout.exerciseDetails.removeAll { $0.id == exerciseID }
                                                store.upsertCompletedWorkout(workout)
                                                store.persist()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if entry.kind == .completed {
                WideActionButton(title: "Import Previous Activity", tint: .blue) {
                    isImportingPreviousActivity = true
                }
            }
        }
        .navigationTitle(entry.statusTitle.isEmpty ? entry.title : entry.statusTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingExercise) { exercise in
            CompletedExerciseEditorView(
                title: "Edit Exercise",
                initialExercise: exercise
            ) { updatedExercise in
                guard var workout = completedWorkout else { return }
                if let index = workout.exerciseDetails.firstIndex(where: { $0.id == updatedExercise.id }) {
                    workout.exerciseDetails[index] = updatedExercise
                    store.upsertCompletedWorkout(workout)
                    store.persist()
                }
            }
        }
        .sheet(isPresented: $isAddingExercise) {
            CompletedExerciseEditorView(
                title: "Add Exercise",
                initialExercise: nil
            ) { newExercise in
                guard var workout = completedWorkout else { return }
                workout.exerciseDetails.append(newExercise)
                store.upsertCompletedWorkout(workout)
                store.persist()
            }
        }
        .sheet(isPresented: $isImportingPreviousActivity) {
            PreviousWorkoutPicker(
                workouts: previousLoggedWorkouts
            ) { selectedWorkout in
                guard var workout = completedWorkout else { return }
                workout.exerciseDetails.append(contentsOf: copiedExercises(from: selectedWorkout))
                store.upsertCompletedWorkout(workout)
                store.persist()
            }
        }
    }

    private func copiedExercises(from workout: CompletedWorkoutSummary) -> [CompletedExerciseDetail] {
        workout.exerciseDetails.map { exercise in
            CompletedExerciseDetail(
                id: UUID(),
                title: exercise.title,
                sets: exercise.sets,
                reps: exercise.reps,
                notes: exercise.notes
            )
        }
    }
}

private struct CompletedExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let title: String
    let initialExercise: CompletedExerciseDetail?
    let onSave: (CompletedExerciseDetail) -> Void

    @State private var exerciseTitle: String
    @State private var selectedBodyPart: ExerciseBodyArea?
    @State private var setsText: String
    @State private var repsText: String
    @State private var notes: String

    init(
        title: String,
        initialExercise: CompletedExerciseDetail?,
        onSave: @escaping (CompletedExerciseDetail) -> Void
    ) {
        self.title = title
        self.initialExercise = initialExercise
        self.onSave = onSave

        _exerciseTitle = State(initialValue: initialExercise?.title ?? "")
        _selectedBodyPart = State(initialValue: initialExercise?.bodyPart)
        _setsText = State(initialValue: initialExercise?.sets.map(String.init) ?? "")
        _repsText = State(initialValue: initialExercise?.reps.map(String.init) ?? "")
        _notes = State(initialValue: initialExercise?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Picker("Body Part", selection: $selectedBodyPart) {
                        Text("None").tag(ExerciseBodyArea?.none)
                        ForEach(ExerciseBodyArea.allCases) { area in
                            Text(area.title).tag(Optional(area))
                        }
                    }
                    .pickerStyle(.menu)

                    Menu {
                        ForEach(exerciseOptions, id: \.self) { option in
                            Button(option) {
                                exerciseTitle = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(exerciseTitle.isEmpty ? "Select exercise" : exerciseTitle)
                                .foregroundStyle(exerciseTitle.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Volume") {
                    TextField("Sets", text: $setsText)
                        .keyboardType(.numberPad)
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if exerciseTitle.isEmpty, let firstOption = exerciseOptions.first {
                    exerciseTitle = firstOption
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            CompletedExerciseDetail(
                                id: initialExercise?.id ?? UUID(),
                                title: exerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                bodyPart: selectedBodyPart,
                                sets: Int(setsText),
                                reps: Int(repsText),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(exerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var exerciseOptions: [String] {
        var options = store.exerciseLibrary
            .filter { exercise in
                guard let selectedBodyPart else { return true }
                return exercise.primaryMuscles.contains(selectedBodyPart)
            }
            .map(\.name)

        if let existingTitle = initialExercise?.title, !existingTitle.isEmpty {
            options.append(existingTitle)
        }

        return Array(Set(options)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}

private struct PreviousWorkoutPicker: View {
    @Environment(\.dismiss) private var dismiss

    let workouts: [CompletedWorkoutSummary]
    let onSelect: (CompletedWorkoutSummary) -> Void

    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    Text("No other workouts with saved exercises are available yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workouts) { workout in
                        Button {
                            onSelect(workout)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.primary)

                                Text(workout.activityType)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(importSummary(for: workout))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Previous Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func importSummary(for workout: CompletedWorkoutSummary) -> String {
        let exerciseCount = workout.exerciseDetails.count
        if exerciseCount == 1 {
            return "1 exercise will be imported"
        }

        return "\(exerciseCount) exercises will be imported"
    }
}

private struct SettingsScreen: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthSyncController: HealthSyncController
    @State private var editingLocation: LocationItem?
    @State private var isAddingLocation = false
    @State private var editingEquipment: EquipmentItem?
    @State private var isAddingEquipment = false
    @State private var editingExercise: ExerciseLibraryItem?
    @State private var isAddingExercise = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScreenScrollContainer {
                    SectionTitle(title: "Apple Health")
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Health Workout Import")
                                    .font(.headline)
                                Text("Connect Apple Health and refresh to pull workouts into Activity. Apple only shows the permission prompt the first time.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            VStack(spacing: 10) {
                                Text(store.healthSyncState.title)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(healthStateColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if healthAuthorizationStatus == .notDetermined {
                                    WideActionButton(title: "Connect Apple Health", tint: .blue) {
                                        Task {
                                            await healthSyncController.connectAndRefresh(using: store)
                                        }
                                    }
                                } else {
                                    WideActionButton(title: "Refresh Data", tint: .green) {
                                        Task {
                                            await healthSyncController.refresh(using: store)
                                        }
                                    }
                                }

                                if shouldShowHealthSettingsHelp {
                                    Text("If permissions still look wrong, open Settings and verify Health access for this app, then return here to refresh.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    WideActionButton(title: "Open Settings", tint: .gray) {
                                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                        openURL(settingsURL)
                                    }
                                }
                            }
                        }
                    }

                    HStack {
                        SectionTitle(title: "Locations")
                        Spacer()
                        Button {
                            isAddingLocation = true
                        } label: {
                            Label("Add Location", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    VStack(spacing: 10) {
                        if store.locations.isEmpty {
                            AppCard {
                                EmptyCardMessage(message: "No saved locations yet. Add one so plans can set watch defaults.")
                            }
                        } else {
                            ForEach(store.locations) { location in
                                AppCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top) {
                                            Text(location.name)
                                                .font(.headline)

                                            Spacer()

                                            HStack(spacing: 8) {
                                                SmallIconButton(systemImage: "pencil") {
                                                    editingLocation = location
                                                }

                                                SmallIconButton(systemImage: "trash", tint: .red) {
                                                    store.removeLocation(id: location.id)
                                                    store.persist()
                                                }
                                            }
                                        }

                                        Text(locationEquipmentSummary(for: location))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    HStack {
                        SectionTitle(title: "Equipment Catalog")
                        Spacer()
                        Button {
                            isAddingEquipment = true
                        } label: {
                            Label("Add Equipment", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(store.equipmentCatalog) { equipment in
                            AppCard {
                                HStack {
                                    Text(equipment.name)
                                        .font(.headline)

                                    Spacer()

                                    HStack(spacing: 8) {
                                        SmallIconButton(systemImage: "pencil") {
                                            editingEquipment = equipment
                                        }

                                        SmallIconButton(systemImage: "trash", tint: .red) {
                                            store.removeEquipmentItem(id: equipment.id)
                                            store.persist()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HStack {
                        SectionTitle(title: "Exercise Library")
                        Spacer()
                        Button {
                            isAddingExercise = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(store.exerciseLibrary) { exercise in
                            AppCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 8) {
                                                Text(exercise.name)
                                                    .font(.headline)

                                                Text(exercise.source.title)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(exercise.source == .custom ? Color.green : Color.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background((exercise.source == .custom ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                                            }

                                            Text(exercise.movementPattern.title)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        HStack(spacing: 8) {
                                            SmallIconButton(systemImage: "pencil") {
                                                editingExercise = exercise
                                            }

                                            if exercise.source == .custom {
                                                SmallIconButton(systemImage: "trash", tint: .red) {
                                                    store.removeExerciseLibraryItem(id: exercise.id)
                                                    store.persist()
                                                }
                                            }
                                        }
                                    }

                                    Text(exercise.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    if !exercise.instructions.isEmpty {
                                        Text("How: \(exercise.instructions)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    FlexibleTagRow(tags: exercise.primaryMuscles.map(\.title))

                                    FlexibleTagRow(tags: exercise.requiredEquipment.map(\.title))
                                }
                            }
                        }
                    }

                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $editingLocation) { location in
                    LocationEditorView(
                        title: "Edit Location",
                        initialLocation: location,
                        equipmentCatalog: store.equipmentCatalog
                    ) { updatedLocation in
                        store.upsertLocation(updatedLocation)
                        store.persist()
                    }
                }
                .sheet(isPresented: $isAddingLocation) {
                    LocationEditorView(
                        title: "Add Location",
                        initialLocation: nil,
                        equipmentCatalog: store.equipmentCatalog
                    ) { newLocation in
                        store.upsertLocation(newLocation)
                        store.persist()
                    }
                }
                .sheet(item: $editingEquipment) { equipment in
                    EquipmentEditorView(
                        title: "Edit Equipment",
                        initialEquipment: equipment
                    ) { updatedEquipment in
                        store.upsertEquipmentItem(updatedEquipment)
                        store.persist()
                    }
                }
                .sheet(isPresented: $isAddingEquipment) {
                    EquipmentEditorView(
                        title: "Add Equipment",
                        initialEquipment: nil
                    ) { newEquipment in
                        store.upsertEquipmentItem(newEquipment)
                        store.persist()
                    }
                }
                .sheet(item: $editingExercise) { exercise in
                    ExerciseEditorView(
                        title: "Edit Exercise",
                        initialExercise: exercise
                    ) { updatedExercise in
                        store.upsertExerciseLibraryItem(updatedExercise)
                        store.persist()
                    }
                }
                .sheet(isPresented: $isAddingExercise) {
                    ExerciseEditorView(
                        title: "Add Exercise",
                        initialExercise: nil
                    ) { newExercise in
                        store.upsertExerciseLibraryItem(newExercise)
                        store.persist()
                    }
                }
            }
        }
    }

    private func locationEquipmentSummary(for location: LocationItem) -> String {
        if !location.equipmentIDs.isEmpty {
            return store.equipmentSummary(for: location.equipmentIDs)
        }

        return location.equipmentSummary
    }

    private var healthStateColor: Color {
        switch store.healthSyncState {
        case .notConnected:
            Color.secondary
        case .connected, .refreshed:
            Color.green
        case .refreshing:
            Color.blue
        case .failed:
            Color.red
        }
    }

    private var healthAuthorizationStatus: HKAuthorizationStatus {
        guard healthSyncController.isHealthDataAvailable else {
            return .notDetermined
        }

        return healthSyncController.authorizationStatus()
    }

    private var shouldShowHealthSettingsHelp: Bool {
        if healthAuthorizationStatus == .sharingDenied {
            return true
        }

        if case .failed = store.healthSyncState {
            return true
        }

        return false
    }
}

private struct ScreenIntro: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ScreenScrollContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

private struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
    }
}

private struct GoalRow: View {
    let index: Int
    let goal: GoalItem
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))

                Text(goal.sourceKind == .event ? "Event goal" : "Recurring activity")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let emphasis = goal.emphasis {
                    Text(emphasis.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let onDelete {
                    SmallIconButton(systemImage: "trash", tint: .red, action: onDelete)
                }

                Image(systemName: "line.3.horizontal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GoalDropDelegate: DropDelegate {
    let targetGoal: GoalItem
    let store: AppStore
    @Binding var draggedGoal: GoalItem?

    func dropEntered(info: DropInfo) {
        guard
            let draggedGoal,
            draggedGoal != targetGoal,
            let fromIndex = store.goals.firstIndex(of: draggedGoal),
            let toIndex = store.goals.firstIndex(of: targetGoal)
        else {
            return
        }

        if store.goals[toIndex] != draggedGoal {
            withAnimation {
                store.moveGoals(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGoal = nil
        store.persist()
        return true
    }
}

private struct FeatureRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
        }
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyCardMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlexibleTagRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedTags, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunkedTags: [[String]] {
        stride(from: 0, to: tags.count, by: 3).map { index in
            Array(tags[index..<min(index + 3, tags.count)])
        }
    }
}

private struct WideActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

private struct SmallIconButton: View {
    let systemImage: String
    var tint: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .foregroundStyle(tint)
        .buttonStyle(.plain)
    }
}

private struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (String, GoalEmphasis) -> Void

    @State private var selectedActivityTitle = WorkoutActivityCatalog.titles.first ?? "Other"
    @State private var emphasis: GoalEmphasis = .maintain

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Activity Type", selection: $selectedActivityTitle) {
                        ForEach(WorkoutActivityCatalog.titles, id: \.self) { title in
                            Text(title).tag(title)
                        }
                    }

                    Text("Matches the Apple Health workout types used for manual workout logging.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Emphasis") {
                    Picker("Emphasis", selection: $emphasis) {
                        ForEach(GoalEmphasis.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedActivityTitle, emphasis)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RoutineActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialRoutineActivity: RoutineActivity?
    let activityTypeOptions: [String]
    let isTrainingActivity: Bool
    let lockedActivityType: String?
    let allowedBodyAreas: [ExerciseBodyArea]?
    let onSave: (RoutineActivity) -> Void

    @State private var name: String
    @State private var selectedActivityType: String
    @State private var selectedWeekdays: Set<Weekday>
    @State private var selectedFocusAreas: Set<ExerciseBodyArea>
    @State private var bodyPartWeekdays: [ExerciseBodyArea: Set<Weekday>]

    init(
        title: String,
        initialRoutineActivity: RoutineActivity?,
        activityTypeOptions: [String],
        isTrainingActivity: Bool = false,
        lockedActivityType: String? = nil,
        allowedBodyAreas: [ExerciseBodyArea]? = nil,
        onSave: @escaping (RoutineActivity) -> Void
    ) {
        self.title = title
        self.initialRoutineActivity = initialRoutineActivity
        self.activityTypeOptions = activityTypeOptions
        self.isTrainingActivity = isTrainingActivity
        self.lockedActivityType = lockedActivityType
        self.allowedBodyAreas = allowedBodyAreas
        self.onSave = onSave

        _name = State(initialValue: initialRoutineActivity?.title ?? "")
        _selectedActivityType = State(
            initialValue: initialRoutineActivity?.activityType
                ?? activityTypeOptions.first
                ?? ""
        )
        _selectedWeekdays = State(initialValue: Set(initialRoutineActivity?.scheduledWeekdays ?? []))

        let existingFocusAreas = initialRoutineActivity?.focusAreas ?? []
        let defaultFocusAreas: [ExerciseBodyArea]
        if !existingFocusAreas.isEmpty {
            defaultFocusAreas = existingFocusAreas
        } else if isTrainingActivity {
            if let allowedBodyAreas, !allowedBodyAreas.isEmpty {
                defaultFocusAreas = allowedBodyAreas
            } else {
                defaultFocusAreas = ExerciseBodyArea.allCases
            }
        } else {
            defaultFocusAreas = []
        }
        _selectedFocusAreas = State(initialValue: Set(defaultFocusAreas))

        let existingSchedules = initialRoutineActivity?.bodyPartSchedules ?? []
        let initialBodyPartWeekdays: [ExerciseBodyArea: Set<Weekday>]
        if !existingSchedules.isEmpty {
            initialBodyPartWeekdays = Dictionary(
                uniqueKeysWithValues: existingSchedules.map { pref in
                    (pref.bodyPart, Set(pref.weekdays))
                }
            )
        } else if let allowedBodyAreas, !allowedBodyAreas.isEmpty {
            initialBodyPartWeekdays = Dictionary(
                uniqueKeysWithValues: allowedBodyAreas.map { area in
                    (area, [])
                }
            )
        } else {
            initialBodyPartWeekdays = Dictionary(
                uniqueKeysWithValues: ExerciseBodyArea.allCases.map { area in
                    (area, [])
                }
            )
        }
        _bodyPartWeekdays = State(initialValue: initialBodyPartWeekdays)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isTrainingActivity {
                    Section {
                        HStack {
                            Text("Activity Type")
                            Spacer()
                            Text(lockedActivityType ?? selectedActivityType)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Activity") {
                        Picker("Activity Type", selection: $selectedActivityType) {
                            ForEach(resolvedActivityTypeOptions, id: \.self) { activityType in
                                Text(activityType).tag(activityType)
                            }
                        }
                    }

                    Section("Typical Days") {
                        WeekdayChipsRow(selectedWeekdays: $selectedWeekdays)
                    }
                }

                if isTrainingActivity {
                    Section("Target Body Parts") {
                        ForEach(allowedBodyAreas ?? ExerciseBodyArea.allCases) { area in
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(
                                    area.title,
                                    isOn: Binding(
                                        get: { selectedFocusAreas.contains(area) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedFocusAreas.insert(area)
                                            } else {
                                                selectedFocusAreas.remove(area)
                                            }
                                        }
                                    )
                                )

                                if selectedFocusAreas.contains(area) {
                                    WeekdayChipsRow(
                                        selectedWeekdays: Binding(
                                            get: { bodyPartWeekdays[area] ?? [] },
                                            set: { newValue in
                                                bodyPartWeekdays[area] = newValue
                                            }
                                        )
                                    )
                                    .padding(.leading, 24)
                                }
                            }
                        }
                    }
                }

            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let routineActivity = RoutineActivity(
                            id: initialRoutineActivity?.id ?? UUID(),
                            title: isTrainingActivity
                                ? (lockedActivityType ?? selectedActivityType)
                                : selectedActivityType,
                            activityType: lockedActivityType ?? selectedActivityType,
                            focusAreas: isTrainingActivity
                                ? ExerciseBodyArea.allCases.filter { selectedFocusAreas.contains($0) }
                                : (initialRoutineActivity?.focusAreas ?? []),
                            scheduledWeekdays: Weekday.allCases.filter { selectedWeekdays.contains($0) },
                            defaultLocationID: nil,
                            defaultDurationMinutes: nil,
                            bodyPartSchedules: bodyPartWeekdays
                                .filter { selectedFocusAreas.contains($0.key) && !$0.value.isEmpty }
                                .map { entry in
                                    BodyPartSchedulePreference(
                                        bodyPart: entry.key,
                                        weekdays: Array(entry.value).sorted { $0.rawValue < $1.rawValue }
                                    )
                                },
                            isTrainingTemplate: initialRoutineActivity?.isTrainingTemplate ?? isTrainingActivity
                        )
                        onSave(routineActivity)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if isTrainingActivity {
            return !selectedFocusAreas.isEmpty
        }

        return !selectedActivityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedActivityTypeOptions: [String] {
        let currentType = selectedActivityType.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(Set(activityTypeOptions + [currentType]))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }
}

private struct WeekdayChipsRow: View {
    @Binding var selectedWeekdays: Set<Weekday>

    private let orderedWeekdays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays) { weekday in
                let isSelected = selectedWeekdays.contains(weekday)
                Text(shortLabel(for: weekday))
                    .font(.caption2.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .onTapGesture {
                        if isSelected {
                            selectedWeekdays.remove(weekday)
                        } else {
                            selectedWeekdays.insert(weekday)
                        }
                    }
            }
        }
    }

    private func shortLabel(for weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "Th"
        case .friday: return "F"
        case .saturday: return "Sa"
        case .sunday: return "Su"
        }
    }
}

private struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialLocation: LocationItem?
    let equipmentCatalog: [EquipmentItem]
    let onSave: (LocationItem) -> Void

    @State private var name: String
    @State private var selectedEquipmentIDs: Set<UUID>

    init(
        title: String,
        initialLocation: LocationItem?,
        equipmentCatalog: [EquipmentItem],
        onSave: @escaping (LocationItem) -> Void
    ) {
        self.title = title
        self.initialLocation = initialLocation
        self.equipmentCatalog = equipmentCatalog
        self.onSave = onSave

        _name = State(initialValue: initialLocation?.name ?? "")
        _selectedEquipmentIDs = State(initialValue: Set(initialLocation?.equipmentIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Available Equipment") {
                    if equipmentCatalog.isEmpty {
                        Text("No equipment defined yet. Add equipment from Settings first.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(equipmentCatalog) { equipment in
                            Toggle(
                                equipment.name,
                                isOn: Binding(
                                    get: { selectedEquipmentIDs.contains(equipment.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedEquipmentIDs.insert(equipment.id)
                                        } else {
                                            selectedEquipmentIDs.remove(equipment.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let selectedNames = equipmentCatalog
                            .filter { selectedEquipmentIDs.contains($0.id) }
                            .map(\.name)
                            .sorted()
                        let location = LocationItem(
                            id: initialLocation?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            equipmentSummary: selectedNames.joined(separator: ", "),
                            equipmentIDs: Array(selectedEquipmentIDs).sorted { lhs, rhs in
                                let lhsName = equipmentCatalog.first(where: { $0.id == lhs })?.name ?? ""
                                let rhsName = equipmentCatalog.first(where: { $0.id == rhs })?.name ?? ""
                                return lhsName < rhsName
                            }
                        )
                        onSave(location)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct EquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialEquipment: EquipmentItem?
    let onSave: (EquipmentItem) -> Void

    @State private var name: String

    init(
        title: String,
        initialEquipment: EquipmentItem?,
        onSave: @escaping (EquipmentItem) -> Void
    ) {
        self.title = title
        self.initialEquipment = initialEquipment
        self.onSave = onSave
        _name = State(initialValue: initialEquipment?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipment") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            EquipmentItem(
                                id: initialEquipment?.id ?? UUID(),
                                name: trimmedName
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialExercise: ExerciseLibraryItem?
    let onSave: (ExerciseLibraryItem) -> Void

    @State private var name: String
    @State private var movementPattern: ExerciseMovementPattern
    @State private var skillLevel: ExerciseSkillLevel
    @State private var notes: String
    @State private var instructions: String
    @State private var primaryMuscles: Set<ExerciseBodyArea>
    @State private var goalSupportTagsText: String
    @State private var isUnilateral: Bool
    @State private var requiredEquipment: Set<ExerciseEquipmentKind>

    init(
        title: String,
        initialExercise: ExerciseLibraryItem?,
        onSave: @escaping (ExerciseLibraryItem) -> Void
    ) {
        self.title = title
        self.initialExercise = initialExercise
        self.onSave = onSave

        _name = State(initialValue: initialExercise?.name ?? "")
        _movementPattern = State(initialValue: initialExercise?.movementPattern ?? .squat)
        _skillLevel = State(initialValue: initialExercise?.skillLevel ?? .beginner)
        _notes = State(initialValue: initialExercise?.notes ?? "")
        _instructions = State(initialValue: initialExercise?.instructions ?? "")
        _primaryMuscles = State(initialValue: Set(initialExercise?.primaryMuscles ?? []))
        _goalSupportTagsText = State(initialValue: initialExercise?.goalSupportTags.joined(separator: ", ") ?? "")
        _isUnilateral = State(initialValue: initialExercise?.isUnilateral ?? false)
        _requiredEquipment = State(initialValue: Set(initialExercise?.requiredEquipment ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(ExerciseMovementPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }

                    Picker("Skill Level", selection: $skillLevel) {
                        ForEach(ExerciseSkillLevel.allCases) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }

                    Toggle("Unilateral", isOn: $isUnilateral)
                }

                Section("Equipment") {
                    ForEach(ExerciseEquipmentKind.allCases) { equipment in
                        Toggle(
                            equipment.title,
                            isOn: Binding(
                                get: { requiredEquipment.contains(equipment) },
                                set: { isSelected in
                                    if isSelected {
                                        requiredEquipment.insert(equipment)
                                    } else {
                                        requiredEquipment.remove(equipment)
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Target Body Parts") {
                    ForEach(ExerciseBodyArea.allCases) { area in
                        Toggle(
                            area.title,
                            isOn: Binding(
                                get: { primaryMuscles.contains(area) },
                                set: { isSelected in
                                    if isSelected {
                                        primaryMuscles.insert(area)
                                    } else {
                                        primaryMuscles.remove(area)
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Details") {
                    TextField("Goal Support Tags", text: $goalSupportTagsText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Short description", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Simple instructions", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = ExerciseLibraryItem(
                            id: initialExercise?.id ?? UUID(),
                            name: trimmedName,
                            movementPattern: movementPattern,
                            requiredEquipment: requiredEquipment.sorted { $0.title < $1.title },
                            primaryMuscles: ExerciseBodyArea.allCases.filter { primaryMuscles.contains($0) },
                            goalSupportTags: splitList(goalSupportTagsText),
                            skillLevel: skillLevel,
                            isUnilateral: isUnilateral,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                            source: initialExercise?.source ?? .custom
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitList(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
        .environmentObject(HealthSyncController())
}
