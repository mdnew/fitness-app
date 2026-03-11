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
    @State private var selectedLocationName = ""
    @State private var selectedDuration = 20

    var body: some View {
        Group {
            switch phase {
            case .start:
                StartWorkoutView(
                    locationName: currentLocationName,
                    duration: selectedDuration,
                    onStart: { phase = .currentExercise },
                    onEdit: { phase = .editDefaults }
                )
            case .editDefaults:
                EditDefaultsView(
                    locations: store.locations.map(\.name),
                    selectedLocationName: $selectedLocationName,
                    selectedDuration: $selectedDuration,
                    onSave: { phase = .start }
                )
            case .currentExercise:
                CurrentExerciseView(
                    exercise: currentExercise,
                    progressText: "\(selectedExerciseIndex + 1) / \(store.currentWorkout.exercises.count)",
                    onComplete: completeExercise,
                    onOverride: skipExercise,
                    onEndWorkout: { phase = .workoutComplete }
                )
            case .workoutComplete:
                WorkoutCompleteView(
                    locationName: currentLocationName,
                    duration: selectedDuration,
                    onDone: resetWorkout
                )
            }
        }
        .onAppear {
            selectedLocationName = store.defaultLocation?.name ?? store.locations.first?.name ?? "No Location"
            selectedDuration = store.todayRoutineDay?.defaultDurationMinutes ?? store.currentWorkout.plannedDurationMinutes
        }
    }

    private var currentExercise: PlannedExercise {
        let safeIndex = min(selectedExerciseIndex, max(store.currentWorkout.exercises.count - 1, 0))
        return store.currentWorkout.exercises[safeIndex]
    }

    private var currentLocationName: String {
        selectedLocationName.isEmpty ? (store.defaultLocation?.name ?? "No Location") : selectedLocationName
    }

    private func completeExercise() {
        if selectedExerciseIndex < store.currentWorkout.exercises.count - 1 {
            selectedExerciseIndex += 1
        } else {
            phase = .workoutComplete
        }
    }

    private func skipExercise() {
        completeExercise()
    }

    private func resetWorkout() {
        selectedExerciseIndex = 0
        phase = .start
    }
}

private struct StartWorkoutView: View {
    let locationName: String
    let duration: Int
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Start Workout")
                .font(.headline)

            VStack(spacing: 4) {
                Text(locationName)
                Text("\(duration) min")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)

            Button("Edit", action: onEdit)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

private struct EditDefaultsView: View {
    let locations: [String]
    @Binding var selectedLocationName: String
    @Binding var selectedDuration: Int
    let onSave: () -> Void

    var body: some View {
        Form {
            Picker("Location", selection: $selectedLocationName) {
                ForEach(locations, id: \.self) { location in
                    Text(location).tag(location)
                }
            }

            Picker("Duration", selection: $selectedDuration) {
                ForEach([10, 15, 20, 30, 45], id: \.self) { duration in
                    Text("\(duration) min").tag(duration)
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
    let onComplete: () -> Void
    let onOverride: () -> Void
    let onEndWorkout: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(exercise.title)
                    .font(.headline)

                Text(exercise.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timer: 00:00")
                    Text("Heart Rate: --")
                }
                .font(.caption2)

                Button("Complete", action: onComplete)
                    .buttonStyle(.borderedProminent)

                Button("Override", action: onOverride)
                    .buttonStyle(.bordered)

                Button("End Workout", action: onEndWorkout)
                    .tint(.red)
            }
            .padding()
        }
    }
}

private struct WorkoutCompleteView: View {
    let locationName: String
    let duration: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Workout Saved")
                .font(.headline)
            Text(locationName)
                .font(.caption)
            Text("\(duration) min")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    WatchRootView()
        .environmentObject(AppStore())
}
