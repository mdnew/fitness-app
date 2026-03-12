import SwiftUI

@main
struct FitnessWatchAppApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
        }
    }
}

private enum WorkoutPhase {
    case start
    case editDefaults
    case currentExercise
    case workoutComplete
}

private struct WatchRootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var phase: WorkoutPhase = .start
    @State private var selectedExerciseIndex = 0
    @State private var selectedLocationID: UUID?
    @State private var selectedDuration = 20
    @State private var selectedManualFocusAreas: Set<ExerciseBodyArea> = []
    @State private var lastSavedExerciseCount = 0
    @State private var didSaveWorkout = false

    var body: some View {
        Group {
            switch phase {
            case .start:
                StartWorkoutView(
                    focusSummary: startFocusSummary,
                    locationName: currentLocationName,
                    duration: selectedDuration,
                    onStart: startWorkout,
                    onEdit: { phase = .editDefaults }
                )
            case .editDefaults:
                EditDefaultsView(
                    locations: store.locations,
                    selectedLocationID: $selectedLocationID,
                    selectedDuration: $selectedDuration,
                    selectedManualFocusAreas: $selectedManualFocusAreas,
                    onSave: { phase = .start }
                )
            case .currentExercise:
                if let currentExercise {
                    CurrentExerciseView(
                        exercise: currentExercise.plannedExercise,
                        progressText: "\(selectedExerciseIndex + 1) / \(trackedExerciseCount)",
                        completedCountText: "\(store.completedTrackedExerciseCount) checked",
                        onComplete: completeExercise,
                        onSkip: skipExercise,
                        onEndWorkout: finishWorkout
                    )
                }
            case .workoutComplete:
                WorkoutCompleteView(
                    locationName: currentLocationName,
                    savedExerciseCount: lastSavedExerciseCount,
                    didSaveWorkout: didSaveWorkout,
                    onDone: resetWorkout
                )
            }
        }
        .onAppear {
            selectedLocationID = selectedLocationID ?? store.defaultLocation?.id ?? store.locations.first?.id
            selectedDuration = store.todayRoutineDay?.defaultDurationMinutes ?? 20
            if store.trackedWorkoutSession != nil {
                phase = .currentExercise
            }
        }
    }

    private var trackedExerciseCount: Int {
        store.trackedWorkoutSession?.exercises.count ?? 0
    }

    private var startFocusSummary: String {
        if let routineDay = store.todayRoutineDay {
            return routineDay.focusSummary
        }

        let selectedAreas = ExerciseBodyArea.allCases.filter { selectedManualFocusAreas.contains($0) }
        return selectedAreas.isEmpty ? "Pick body parts in Edit" : selectedAreas.map(\.title).joined(separator: ", ")
    }

    private var currentExercise: TrackedExerciseState? {
        guard let session = store.trackedWorkoutSession, !session.exercises.isEmpty else { return nil }
        let safeIndex = min(selectedExerciseIndex, max(session.exercises.count - 1, 0))
        return session.exercises[safeIndex]
    }

    private var currentLocationName: String {
        guard
            let selectedLocationID,
            let location = store.locations.first(where: { $0.id == selectedLocationID })
        else {
            return "No Location"
        }

        return location.name
    }

    private func startWorkout() {
        if let routineDay = store.todayRoutineDay {
            _ = store.startTrackedWorkout(
                for: routineDay,
                targetDate: .now,
                locationID: selectedLocationID,
                durationMinutes: selectedDuration
            )
        } else {
            let selectedAreas = ExerciseBodyArea.allCases.filter { selectedManualFocusAreas.contains($0) }
            guard !selectedAreas.isEmpty else {
                phase = .editDefaults
                return
            }

            _ = store.startTrackedWorkout(
                focusAreas: selectedAreas,
                targetDate: .now,
                locationID: selectedLocationID,
                durationMinutes: selectedDuration
            )
        }
        selectedExerciseIndex = 0
        phase = trackedExerciseCount > 0 ? .currentExercise : .start
    }

    private func completeExercise() {
        guard let currentExercise else { return }
        if !currentExercise.isCompleted {
            store.toggleTrackedExercise(id: currentExercise.id)
        }
        advanceExercise()
    }

    private func skipExercise() {
        advanceExercise()
    }

    private func advanceExercise() {
        if selectedExerciseIndex < trackedExerciseCount - 1 {
            selectedExerciseIndex += 1
        } else {
            finishWorkout()
        }
    }

    private func finishWorkout() {
        if let pendingWorkout = store.finalizeTrackedWorkoutSession() {
            lastSavedExerciseCount = pendingWorkout.exerciseDetails.count
            didSaveWorkout = true
        } else {
            store.discardTrackedWorkoutSession()
            lastSavedExerciseCount = 0
            didSaveWorkout = false
        }
        phase = .workoutComplete
    }

    private func resetWorkout() {
        selectedExerciseIndex = 0
        phase = .start
    }
}

private struct StartWorkoutView: View {
    let focusSummary: String
    let locationName: String
    let duration: Int
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Track")
                .font(.headline)
            Text(focusSummary)
                .font(.caption)
                .multilineTextAlignment(.center)
            Text("\(duration) min at \(locationName)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)

            Button("Edit", action: onEdit)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

private struct EditDefaultsView: View {
    let locations: [LocationItem]
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDuration: Int
    @Binding var selectedManualFocusAreas: Set<ExerciseBodyArea>
    let onSave: () -> Void

    var body: some View {
        Form {
            Picker("Location", selection: $selectedLocationID) {
                ForEach(locations) { location in
                    Text(location.name).tag(Optional(location.id))
                }
            }

            Picker("Duration", selection: $selectedDuration) {
                ForEach([10, 15, 20, 30, 45], id: \.self) { duration in
                    Text("\(duration) min").tag(duration)
                }
            }

            Section("Manual Focus") {
                ForEach(ExerciseBodyArea.allCases) { area in
                    Toggle(
                        area.title,
                        isOn: Binding(
                            get: { selectedManualFocusAreas.contains(area) },
                            set: { isSelected in
                                if isSelected {
                                    selectedManualFocusAreas.insert(area)
                                } else {
                                    selectedManualFocusAreas.remove(area)
                                }
                            }
                        )
                    )
                }
            }

            Button("Save", action: onSave)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct CurrentExerciseView: View {
    let exercise: PlannedExercise
    let progressText: String
    let completedCountText: String
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onEndWorkout: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(completedCountText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(exercise.title)
                    .font(.headline)

                Text(exercise.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Did It", action: onComplete)
                    .buttonStyle(.borderedProminent)

                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)

                Button("Finish", action: onEndWorkout)
                    .tint(.red)
            }
            .padding()
        }
    }
}

private struct WorkoutCompleteView: View {
    let locationName: String
    let savedExerciseCount: Int
    let didSaveWorkout: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(didSaveWorkout ? "Track Saved" : "Nothing Saved")
                .font(.headline)
            Text(locationName)
                .font(.caption)
            Text(messageText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var messageText: String {
        guard didSaveWorkout else {
            return "Check at least one exercise next time to save this session."
        }

        let exerciseSummary = savedExerciseCount == 1 ? "1 exercise" : "\(savedExerciseCount) exercises"
        return "Saved \(exerciseSummary). It will attach when the matching Apple Health workout appears on iPhone."
    }
}

#Preview {
    WatchRootView()
        .environmentObject(AppStore())
}
