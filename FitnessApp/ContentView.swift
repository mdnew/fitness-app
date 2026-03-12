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
                    Label("Routine", systemImage: "calendar")
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
    @State private var editingRoutineDay: RoutineDay?
    @State private var isAddingRoutineDay = false

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Training Plan")
                            .font(.headline)
                        Text("Edit your lifting days, target body parts, and default watch workout settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

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

                HStack {
                    SectionTitle(title: "Weekly Plan")
                    Spacer()
                    Button {
                        isAddingRoutineDay = true
                    } label: {
                        Label("Add Day", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    if store.routineDays.isEmpty {
                        AppCard {
                            EmptyCardMessage(message: "No routine days yet. Add one to prefill workout defaults on Apple Watch.")
                        }
                    } else {
                        ForEach(store.routineDays) { routineDay in
                            AppCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(routineDay.weekday.title)
                                                .font(.headline)
                                            Text(routineDay.focusSummary)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        HStack(spacing: 8) {
                                            SmallIconButton(systemImage: "pencil") {
                                                editingRoutineDay = routineDay
                                            }

                                            SmallIconButton(systemImage: "trash", tint: .red) {
                                                store.removeRoutineDay(id: routineDay.id)
                                                store.persist()
                                            }
                                        }
                                    }

                                    Label(routineDefaultsText(for: routineDay), systemImage: "figure.strengthtraining.traditional")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingRoutineDay) { routineDay in
                RoutineDayEditorView(
                    title: "Edit Routine Day",
                    initialRoutineDay: routineDay,
                    locations: store.locations,
                    unavailableWeekdays: Set(store.routineDays.map(\.weekday))
                ) { updatedRoutineDay in
                    store.upsertRoutineDay(updatedRoutineDay)
                    store.persist()
                }
            }
            .sheet(isPresented: $isAddingRoutineDay) {
                RoutineDayEditorView(
                    title: "Add Routine Day",
                    initialRoutineDay: nil,
                    locations: store.locations,
                    unavailableWeekdays: Set(store.routineDays.map(\.weekday))
                ) { newRoutineDay in
                    store.upsertRoutineDay(newRoutineDay)
                    store.persist()
                }
            }
        }
    }

    private func routineDefaultsText(for routineDay: RoutineDay) -> String {
        let locationName = store.locations.first(where: { $0.id == routineDay.defaultLocationID })?.name ?? "No location"
        let durationText = routineDay.defaultDurationMinutes.map { "\($0) minutes" } ?? "No duration"
        return "\(durationText) at \(locationName)"
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

}

private struct ActivityScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                SectionTitle(title: "Upcoming")
                if upcomingEntries.isEmpty {
                    AppCard {
                        EmptyCardMessage(message: "No upcoming sessions are scheduled from your routine yet.")
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(upcomingEntries) { entry in
                            ActivityEntryCard(entry: entry)
                        }
                    }
                }

                SectionTitle(title: "Past")
                if pastWorkoutDayGroups.isEmpty {
                    AppCard {
                        EmptyCardMessage(message: pastSessionsEmptyMessage)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(pastWorkoutDayGroups) { group in
                            AppCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(weekdayDateText(for: group.date))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .tracking(0.8)

                                    if let strengthWorkout = group.strengthWorkout {
                                        let entry = activityEntry(for: strengthWorkout)
                                        NavigationLink {
                                            ActivityEntryDetailScreen(entry: entry)
                                        } label: {
                                            StrengthWorkoutSummaryRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if !group.otherWorkouts.isEmpty {
                                        if group.strengthWorkout != nil {
                                            Divider()
                                        }

                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(group.otherWorkouts) { workout in
                                                ReadOnlyWorkoutRow(workout: workout)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var upcomingEntries: [ActivityEntry] {
        let completedDays = Set(strengthWorkouts.map { calendar.startOfDay(for: $0.date) })

        var entries: [ActivityEntry] = []
        guard let startOfToday = calendar.dateInterval(of: .day, for: .now)?.start else {
            return entries
        }

        for offset in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }

            guard let weekday = mappedWeekday(for: date) else {
                continue
            }

            guard let routineDay = store.routineDays.first(where: { $0.weekday == weekday }) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: date)
            guard !completedDays.contains(dayStart) else {
                continue
            }

            let locationName = store.locations.first(where: { $0.id == routineDay.defaultLocationID })?.name ?? "No location"
            let durationText = routineDay.defaultDurationMinutes.map { "\($0) minutes" } ?? "No duration"

            entries.append(
                ActivityEntry(
                    id: "\(routineDay.id.uuidString)-\(dayStart.timeIntervalSince1970)",
                    kind: .planned,
                    workoutID: nil,
                    date: date,
                    title: "Traditional Strength Training",
                    subtitle: routineDay.focusSummary,
                    subtitleTint: .secondary,
                    detail: "\(durationText) at \(locationName)",
                    statusTitle: "Planned",
                    statusTint: .blue,
                    exerciseDetails: [],
                    emptyExerciseMessage: "Suggested exercises are generated when you start a Track session."
                )
            )

            if entries.count == 3 {
                break
            }
        }

        return entries.sorted { $0.date > $1.date }
    }

    private var pastWorkouts: [CompletedWorkoutSummary] {
        importedWorkouts.filter { $0.date < .now }
    }

    private var pastWorkoutDayGroups: [PastWorkoutDayGroup] {
        let groupedWorkouts = Dictionary(grouping: pastWorkouts) { workout in
            calendar.startOfDay(for: workout.date)
        }

        return groupedWorkouts
            .map { day, workouts in
                let sortedWorkouts = workouts.sorted { lhs, rhs in
                    if isTraditionalStrengthWorkout(lhs) != isTraditionalStrengthWorkout(rhs) {
                        return isTraditionalStrengthWorkout(lhs)
                    }

                    return lhs.date > rhs.date
                }

                return PastWorkoutDayGroup(
                    date: day,
                    strengthWorkout: sortedWorkouts.first(where: isTraditionalStrengthWorkout),
                    otherWorkouts: sortedWorkouts.filter { !isTraditionalStrengthWorkout($0) }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var strengthWorkouts: [CompletedWorkoutSummary] {
        importedWorkouts.filter(isTraditionalStrengthWorkout)
    }

    private var importedWorkouts: [CompletedWorkoutSummary] {
        store.history.filter { workout in
            !workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func isTraditionalStrengthWorkout(_ workout: CompletedWorkoutSummary) -> Bool {
        let normalizedActivity = workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedActivity == "traditional strength training"
    }

    private func activityEntry(for workout: CompletedWorkoutSummary) -> ActivityEntry {
        ActivityEntry(
            id: workout.id.uuidString,
            kind: .completed,
            workoutID: workout.id,
            date: workout.date,
            title: workout.activityType,
            subtitle: completedWorkoutSubtitle(for: workout),
            subtitleTint: workout.exerciseDetails.isEmpty ? .secondary : .green,
            detail: completedWorkoutDetail(for: workout),
            statusTitle: "Completed",
            statusTint: .green,
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

    private func mappedWeekday(for date: Date) -> Weekday? {
        let weekdayIndex = calendar.component(.weekday, from: date)
        return Weekday(rawValue: ((weekdayIndex + 5) % 7) + 1)
    }

    private func weekdayDateText(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()).uppercased()
    }

    private var calendar: Calendar {
        .current
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
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes = 20
    @State private var selectedManualFocusAreas: Set<ExerciseBodyArea> = []
    @State private var isShowingManualSetupSheet = false
    @State private var isShowingPlannedStartSheet = false
    @State private var isShowingOtherExerciseSheet = false
    @State private var isShowingFinishSheet = false
    @State private var isShowingDiscardAlert = false
    @State private var finishMessage = ""
    @State private var isShowingFinishMessage = false

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
                                    store.toggleTrackedExercise(id: exercise.id)
                                    store.persist()
                                }
                            }

                            WideActionButton(title: "Other", tint: .gray) {
                                isShowingOtherExerciseSheet = true
                            }
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
                    if let nextPlannedWorkout {
                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Next Planned Workout")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(nextPlannedWorkout.focusSummary)
                                    .font(.headline)
                                Text(nextPlannedWorkout.dateText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("\(nextPlannedWorkout.durationMinutes) min at \(nextPlannedWorkout.locationName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                WideActionButton(title: "Start Planned Workout", tint: .blue) {
                                    isShowingPlannedStartSheet = true
                                }
                            }
                        }
                    } else {
                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("No Planned Workout")
                                    .font(.headline)
                                Text("There is no upcoming planned workout right now. You can still create an unplanned session based on the body parts you want to train.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unplanned Workout")
                                .font(.headline)
                            Text("Create a manual session whenever you want to train something outside your upcoming planned workout.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            WideActionButton(title: "Start Unplanned Workout", tint: .gray) {
                                isShowingManualSetupSheet = true
                            }
                        }
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
                selectedLocationID = selectedLocationID ?? nextPlannedWorkout?.defaultLocationID ?? store.defaultLocation?.id ?? store.locations.first?.id
                selectedDurationMinutes = nextPlannedWorkout?.durationMinutes ?? store.todayRoutineDay?.defaultDurationMinutes ?? 20
            }
            .sheet(isPresented: $isShowingFinishSheet) {
                TrackFinishSheet(
                    checkedExerciseCount: store.completedTrackedExerciseCount,
                    onConfirm: {
                        if let pendingWorkout = store.finalizeTrackedWorkoutSession() {
                            finishMessage = "Saved \(pendingWorkout.exerciseDetails.count) checked exercises. This session will attach when the matching Apple Health workout imports."
                            store.persist()
                            isShowingFinishSheet = false
                            isShowingFinishMessage = true
                        }
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
            .sheet(isPresented: $isShowingPlannedStartSheet) {
                if let nextPlannedWorkout {
                    TrackPlannedStartSheet(
                        locationName: nextPlannedWorkout.locationName,
                        selectedLocationID: $selectedLocationID,
                        selectedDurationMinutes: $selectedDurationMinutes,
                        locations: store.locations,
                        onConfirm: {
                            _ = store.startTrackedWorkout(
                                for: nextPlannedWorkout.routineDay,
                                targetDate: nextPlannedWorkout.date,
                                locationID: selectedLocationID,
                                durationMinutes: selectedDurationMinutes
                            )
                            store.persist()
                            isShowingPlannedStartSheet = false
                        },
                        onCancel: {
                            isShowingPlannedStartSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $isShowingManualSetupSheet) {
                TrackUnplannedStartSheet(
                    selectedLocationID: $selectedLocationID,
                    selectedDurationMinutes: $selectedDurationMinutes,
                    selectedFocusAreas: $selectedManualFocusAreas,
                    locations: store.locations,
                    onConfirm: {
                        _ = store.startTrackedWorkout(
                            focusAreas: ExerciseBodyArea.allCases.filter { selectedManualFocusAreas.contains($0) },
                            targetDate: .now,
                            locationID: selectedLocationID,
                            durationMinutes: selectedDurationMinutes
                        )
                        store.persist()
                        isShowingManualSetupSheet = false
                    },
                    onCancel: {
                        isShowingManualSetupSheet = false
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
        }
    }

    private var trackedSession: TrackedWorkoutSession? {
        store.trackedWorkoutSession
    }

    private var nextPlannedWorkout: TrackPlannedLaunchOption? {
        let calendar = Calendar.current
        let completedDays = Set(
            store.history
                .filter {
                    $0.activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "traditional strength training"
                }
                .map { calendar.startOfDay(for: $0.date) }
        )

        guard let startOfToday = calendar.dateInterval(of: .day, for: .now)?.start else {
            return nil
        }

        for offset in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: date)
            guard !completedDays.contains(dayStart), let routineDay = store.routineDay(for: date) else {
                continue
            }

            let defaultLocationID = routineDay.defaultLocationID
            let locationName = store.locations.first(where: { $0.id == defaultLocationID })?.name ?? "No location"
            let durationMinutes = routineDay.defaultDurationMinutes ?? 20

            return TrackPlannedLaunchOption(
                date: date,
                routineDay: routineDay,
                focusSummary: routineDay.focusSummary,
                defaultLocationID: defaultLocationID,
                locationName: locationName,
                durationMinutes: durationMinutes
            )
        }

        return nil
    }

    @ViewBuilder
    private var trackLocationAndDurationControls: some View {
        Picker("Location", selection: $selectedLocationID) {
            ForEach(store.locations) { location in
                Text(location.name).tag(Optional(location.id))
            }
        }
        .pickerStyle(.menu)

        Picker("Planned Duration", selection: $selectedDurationMinutes) {
            ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                Text("\(duration) min").tag(duration)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct TrackPlannedLaunchOption {
    let date: Date
    let routineDay: RoutineDay
    let focusSummary: String
    let defaultLocationID: UUID?
    let locationName: String
    let durationMinutes: Int

    var dateText: String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()).uppercased()
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

private struct TrackPlannedStartSheet: View {
    let locationName: String
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
                        Text("Double-check the location and duration before generating your suggested workout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Location", selection: $selectedLocationID) {
                            ForEach(locations) { location in
                                Text(location.name).tag(Optional(location.id))
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Planned Duration", selection: $selectedDurationMinutes) {
                            ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                                Text("\(duration) min").tag(duration)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                WideActionButton(title: "Start Workout", tint: .blue, action: onConfirm)
            }
            .navigationTitle(locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

private struct TrackUnplannedStartSheet: View {
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDurationMinutes: Int
    @Binding var selectedFocusAreas: Set<ExerciseBodyArea>
    let locations: [LocationItem]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Target Body Parts") {
                    ForEach(ExerciseBodyArea.allCases) { area in
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
                    }
                }

                Section("Workout Details") {
                    Picker("Location", selection: $selectedLocationID) {
                        ForEach(locations) { location in
                            Text(location.name).tag(Optional(location.id))
                        }
                    }

                    Picker("Planned Duration", selection: $selectedDurationMinutes) {
                        ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                            Text("\(duration) min").tag(duration)
                        }
                    }
                }
            }
            .navigationTitle("Unplanned Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onConfirm)
                        .disabled(selectedFocusAreas.isEmpty)
                }
            }
        }
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

private struct TrackExerciseRow: View {
    let exercise: TrackedExerciseState
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            AppCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(exercise.isCompleted ? .green : .secondary)

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
                    Text(entry.statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entry.statusTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entry.statusTint.opacity(0.12), in: Capsule())

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
                .stroke(entry.statusTint.opacity(0.28), lineWidth: 1)
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
        Text(rowText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 2)
    }

    private var rowText: String {
        "\(workout.activityType) • \(detailText)"
    }

    private var detailText: String {
        let trimmedLocation = workout.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLocation.isEmpty || trimmedLocation.caseInsensitiveCompare("Apple Health") == .orderedSame {
            return "\(workout.durationMinutes) min"
        }

        return "\(workout.durationMinutes) min at \(trimmedLocation)"
    }
}

private struct PastWorkoutDayGroup: Identifiable {
    let date: Date
    let strengthWorkout: CompletedWorkoutSummary?
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
                        Text(entry.statusTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.statusTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.statusTint.opacity(0.12), in: Capsule())
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
        .navigationTitle(entry.statusTitle)
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
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Apple Health Workout Import")
                                        .font(.headline)
                                    Text("Connect Apple Health and refresh to pull workouts into Activity. Apple only shows the permission prompt the first time.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(
                                    title: store.healthSyncState.title,
                                    tint: healthStateColor
                                )
                            }

                            Divider()

                            VStack(spacing: 10) {
                                if healthAuthorizationStatus == .notDetermined {
                                    WideActionButton(title: "Connect Apple Health", tint: .blue) {
                                        Task {
                                            await healthSyncController.connectAndRefresh(using: store)
                                        }
                                    }
                                } else {
                                    WideActionButton(title: "Refresh Workouts", tint: .green) {
                                        Task {
                                            await healthSyncController.refresh(using: store)
                                        }
                                    }
                                }

                                if shouldShowHealthSettingsHelp {
                                    Text("If permissions still look wrong, open Settings and verify Health access for this app, then return here to refresh workouts.")
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
                                EmptyCardMessage(message: "No saved locations yet. Add one so routines can set watch defaults.")
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
                                                    .foregroundStyle(exercise.source == .custom ? .green : .secondary)
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
            .secondary
        case .connected, .refreshed:
            .green
        case .refreshing:
            .blue
        case .failed:
            .red
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

private struct RoutineDayEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialRoutineDay: RoutineDay?
    let locations: [LocationItem]
    let unavailableWeekdays: Set<Weekday>
    let onSave: (RoutineDay) -> Void

    @State private var selectedWeekday: Weekday
    @State private var selectedFocusAreas: Set<ExerciseBodyArea>
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes: Int?

    init(
        title: String,
        initialRoutineDay: RoutineDay?,
        locations: [LocationItem],
        unavailableWeekdays: Set<Weekday>,
        onSave: @escaping (RoutineDay) -> Void
    ) {
        self.title = title
        self.initialRoutineDay = initialRoutineDay
        self.locations = locations
        self.unavailableWeekdays = unavailableWeekdays
        self.onSave = onSave

        _selectedWeekday = State(initialValue: initialRoutineDay?.weekday ?? .monday)
        _selectedFocusAreas = State(initialValue: Set(initialRoutineDay?.focusAreas ?? []))
        _selectedLocationID = State(initialValue: initialRoutineDay?.defaultLocationID)
        _selectedDurationMinutes = State(initialValue: initialRoutineDay?.defaultDurationMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Day") {
                    Picker("Weekday", selection: $selectedWeekday) {
                        ForEach(availableWeekdays, id: \.self) { weekday in
                            Text(weekday.title).tag(weekday)
                        }
                    }
                }

                Section("Target Body Parts") {
                    ForEach(ExerciseBodyArea.allCases) { area in
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
                    }
                }

                Section("Watch Defaults") {
                    Picker("Default Location", selection: $selectedLocationID) {
                        Text("No default").tag(UUID?.none)
                        ForEach(locations) { location in
                            Text(location.name).tag(Optional(location.id))
                        }
                    }

                    Picker("Default Duration", selection: $selectedDurationMinutes) {
                        Text("No default").tag(Int?.none)
                        ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                            Text("\(duration) min").tag(Optional(duration))
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
                        let routineDay = RoutineDay(
                            id: initialRoutineDay?.id ?? UUID(),
                            weekday: selectedWeekday,
                            focusAreas: ExerciseBodyArea.allCases.filter { selectedFocusAreas.contains($0) },
                            defaultLocationID: selectedLocationID,
                            defaultDurationMinutes: selectedDurationMinutes
                        )
                        onSave(routineDay)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var availableWeekdays: [Weekday] {
        let currentWeekday = initialRoutineDay?.weekday
        return Weekday.allCases.filter { weekday in
            weekday == currentWeekday || !unavailableWeekdays.contains(weekday)
        }
    }

    private var canSave: Bool {
        !selectedFocusAreas.isEmpty && !availableWeekdays.isEmpty
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
