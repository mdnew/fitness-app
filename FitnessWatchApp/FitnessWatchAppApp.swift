import SwiftUI
import WatchConnectivity

@main
struct FitnessWatchAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var workoutSender = WatchWorkoutSender()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workoutSender)
        }
    }
}

private enum WatchTrackPhase {
    case chooseActivity
    case targetBodyParts
    case chooseExercise
    case exerciseTimer
}

private struct WatchRootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var workoutSender: WatchWorkoutSender

    @State private var phase: WatchTrackPhase = .chooseActivity
    @State private var selectedActivityType: String = "Traditional Strength Training"
    @State private var selectedBodyParts: Set<ExerciseBodyArea> = []
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes: Int = 20
    @State private var suggestedExercises: [ExerciseLibraryItem] = []
    @State private var activeExercise: ExerciseLibraryItem?
    @State private var totalExerciseDuration: TimeInterval = 0
    @State private var hasActiveWorkout: Bool = false
    @State private var completedExercises: [WatchCompletedExercise] = []

    var body: some View {
        switch phase {
        case .chooseActivity:
            VStack(spacing: 0) {
                ChooseActivityView(
                    onSelectStrength: {
                        beginConfiguration(for: "Traditional Strength Training")
                    },
                    onSelectCore: {
                        beginConfiguration(for: "Core Training")
                    }
                )
                .frame(maxHeight: .infinity)

                if workoutSender.pendingWorkoutCount > 0 {
                    UnsyncedWorkoutsBar(
                        count: workoutSender.pendingWorkoutCount,
                        onRetry: { workoutSender.retrySyncing() }
                    )
                }
            }

        case .targetBodyParts:
            TargetBodyPartsView(
                activityType: selectedActivityType,
                selectedBodyParts: $selectedBodyParts,
                allowedBodyParts: allowedTrainingBodyAreas(for: selectedActivityType),
                locations: store.locations,
                selectedLocationID: $selectedLocationID,
                selectedDurationMinutes: $selectedDurationMinutes,
                onContinue: {
                    loadSuggestedExercises()
                    phase = .chooseExercise
                },
                onCancel: {
                    resetToStart()
                }
            )

        case .chooseExercise:
            ChooseExerciseView(
                activityType: selectedActivityType,
                exercises: suggestedExercises,
                totalExerciseDuration: totalExerciseDuration,
                onSelectExercise: { exercise in
                    activeExercise = exercise
                    if !hasActiveWorkout {
                        hasActiveWorkout = true
                    }
                    phase = .exerciseTimer
                },
                onFinish: {
                    guard hasActiveWorkout else {
                        resetToStart()
                        return
                    }
                    let completedAt = Date()
                    workoutSender.sendWorkout(
                        activityType: selectedActivityType,
                        completedAt: completedAt,
                        durationSeconds: totalExerciseDuration,
                        exercises: completedExercises
                    )
                    resetToStart()
                },
                onCancel: {
                    guard hasActiveWorkout else {
                        resetToStart()
                        return
                    }
                    let completedAt = Date()
                    workoutSender.sendWorkout(
                        activityType: selectedActivityType,
                        completedAt: completedAt,
                        durationSeconds: totalExerciseDuration,
                        exercises: completedExercises
                    )
                    resetToStart()
                }
            )

        case .exerciseTimer:
            if let exercise = activeExercise {
                ExerciseTimerView(
                    exerciseTitle: exercise.name,
                    onFinish: { elapsed in
                        completedExercises.append(WatchCompletedExercise(title: exercise.name, durationSeconds: elapsed))
                        totalExerciseDuration += elapsed
                        phase = .chooseExercise
                    },
                    onCancel: {
                        phase = .chooseExercise
                    }
                )
            } else {
                // Safety fallback – show chooser again.
                ChooseActivityView(
                    onSelectStrength: {
                        beginConfiguration(for: "Traditional Strength Training")
                    },
                    onSelectCore: {
                        beginConfiguration(for: "Core Training")
                    }
                )
            }
        }
    }

    private func beginConfiguration(for activityType: String) {
        selectedActivityType = activityType
        let defaultAreas = defaultBodyParts(for: activityType)
        selectedBodyParts = Set(defaultAreas)
        if selectedLocationID == nil, let firstLocation = store.locations.first {
            selectedLocationID = firstLocation.id
        }
        phase = .targetBodyParts
    }

    private func loadSuggestedExercises() {
        let areas = Array(selectedBodyParts)
        guard !areas.isEmpty else {
            suggestedExercises = []
            return
        }

        let temporaryRoutine = RoutineActivity(
            id: UUID(),
            title: selectedActivityType,
            activityType: selectedActivityType,
            focusAreas: areas,
            scheduledWeekdays: [],
            defaultLocationID: nil,
            defaultDurationMinutes: nil,
            bodyPartSchedules: [],
            isTrainingTemplate: false
        )

        suggestedExercises = store.recommendedExercises(
            for: temporaryRoutine,
            targetDate: .now,
            locationID: nil,
            desiredCount: 6,
            priorPlannedExerciseTitles: []
        )
    }

    private func resetToStart() {
        activeExercise = nil
        suggestedExercises = []
        selectedBodyParts.removeAll()
        totalExerciseDuration = 0
        hasActiveWorkout = false
        completedExercises = []
        phase = .chooseActivity
    }

    private func defaultBodyParts(for activityType: String) -> [ExerciseBodyArea] {
        let today = store.weekday(for: .now)
        if let template = trainingTemplate(for: activityType) {
            let scheduled = template.bodyPartSchedules
                .filter { $0.weekdays.contains(today) }
                .map(\.bodyPart)
            if !scheduled.isEmpty {
                return scheduled
            }
        }
        return allowedTrainingBodyAreas(for: activityType)
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

}

// MARK: - Subviews

private struct ChooseActivityView: View {
    let onSelectStrength: () -> Void
    let onSelectCore: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("FITNESS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)

            Text("Choose an Activity")
                .font(.headline)

            Divider()
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Button(action: onSelectStrength) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue)
                        .overlay(
                            HStack {
                                Text("🏋️‍♂️")
                                Text("Strength Training")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                        )
                        .frame(height: 48)
                }
                .buttonStyle(.plain)

                Button(action: onSelectCore) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue)
                        .overlay(
                            HStack {
                                Text("🔥")
                                Text("Core Training")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                        )
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

private struct TargetBodyPartsView: View {
    let activityType: String
    @Binding var selectedBodyParts: Set<ExerciseBodyArea>
    let allowedBodyParts: [ExerciseBodyArea]
    let locations: [LocationItem]
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDurationMinutes: Int
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section("Target Body Parts") {
                ForEach(allowedBodyParts) { area in
                    Toggle(
                        area.title,
                        isOn: Binding(
                            get: { selectedBodyParts.contains(area) },
                            set: { isOn in
                                if isOn {
                                    selectedBodyParts.insert(area)
                                } else {
                                    selectedBodyParts.remove(area)
                                }
                            }
                        )
                    )
                }
            }

            if !locations.isEmpty {
                Section {
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

                Section {
                    VStack(spacing: 6) {
                        Button("Continue", action: onContinue)
                            .buttonStyle(.borderedProminent)

                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

private struct ChooseExerciseView: View {
    let activityType: String
    let exercises: [ExerciseLibraryItem]
    let totalExerciseDuration: TimeInterval
    let onSelectExercise: (ExerciseLibraryItem) -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(activityType.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)

                Text("Choose an Exercise")
                    .font(.headline)

                HStack(spacing: 4) {
                    Text("Total time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(from: totalExerciseDuration))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                }

                Divider()

                VStack(spacing: 8) {
                    ForEach(exercises, id: \.id) { exercise in
                        Button {
                            onSelectExercise(exercise)
                        } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green)
                                .overlay(
                                    HStack {
                                        Text(exercise.name)
                                            .font(.caption2.weight(.semibold))
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(8)
                                )
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 4)

                VStack(spacing: 6) {
                    Button("Finish", action: onFinish)
                        .buttonStyle(.borderedProminent)

                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let totalHundredths = Int((interval * 100).rounded())
        let hundredths = totalHundredths % 100
        let totalSeconds = max(totalHundredths / 100, 0)
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

private struct ExerciseTimerView: View {
    let exerciseTitle: String
    let onFinish: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var startDate = Date()

    var body: some View {
        VStack(spacing: 8) {
            Text(exerciseTitle)
                .font(.headline)
                .lineLimit(1)

            TimelineView(.periodic(from: startDate, by: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                Text(formattedTime(from: max(0, elapsed)))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }

            Button("Finish") {
                let elapsed = Date().timeIntervalSince(startDate)
                onFinish(max(elapsed, 0))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let totalHundredths = Int((interval * 100).rounded())
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

// MARK: - Unsynced workouts bar

private struct UnsyncedWorkoutsBar: View {
    let count: Int
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text(count == 1 ? "1 workout waiting to sync" : "\(count) workouts waiting to sync")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25))
    }
}

// MARK: - Watch → Phone workout transfer

private struct WatchCompletedExercise: Codable {
    let title: String
    let durationSeconds: TimeInterval
}

private enum WatchWorkoutPayload {
    static let key = "watchWorkout"
    static let id = "id"
    static let activityType = "activityType"
    static let completedAtTimestamp = "completedAtTimestamp"
    static let durationSeconds = "durationSeconds"
    static let exercises = "exercises"
}

private enum WatchWorkoutAck {
    static let key = "watchWorkoutAck"
}

private struct PendingWorkoutToSend: Codable {
    var id: String
    var activityType: String
    var completedAtTimestamp: TimeInterval
    var durationSeconds: TimeInterval
    var exercises: [WatchCompletedExercise]

    init(id: String, activityType: String, completedAtTimestamp: TimeInterval, durationSeconds: TimeInterval, exercises: [WatchCompletedExercise] = []) {
        self.id = id
        self.activityType = activityType
        self.completedAtTimestamp = completedAtTimestamp
        self.durationSeconds = durationSeconds
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey {
        case id, activityType, completedAtTimestamp, durationSeconds, exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        activityType = try c.decode(String.self, forKey: .activityType)
        completedAtTimestamp = try c.decode(TimeInterval.self, forKey: .completedAtTimestamp)
        durationSeconds = try c.decode(TimeInterval.self, forKey: .durationSeconds)
        exercises = try c.decodeIfPresent([WatchCompletedExercise].self, forKey: .exercises) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(activityType, forKey: .activityType)
        try c.encode(completedAtTimestamp, forKey: .completedAtTimestamp)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(exercises, forKey: .exercises)
    }
}

private enum PendingWorkoutsStore {
    static let userDefaultsKey = "fitness.pendingWatchWorkouts"

    static func load() -> [PendingWorkoutToSend] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingWorkoutToSend].self, from: data)) ?? []
    }

    static func save(_ pending: [PendingWorkoutToSend]) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

@MainActor
final class WatchWorkoutSender: NSObject, ObservableObject {
    @Published private(set) var pendingWorkoutCount: Int = 0

    override init() {
        super.init()
        pendingWorkoutCount = PendingWorkoutsStore.load().count
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends workout data to the phone; the phone saves it to HealthKit. Persists for retry if transfer fails.
    fileprivate func sendWorkout(activityType: String, completedAt: Date, durationSeconds: TimeInterval, exercises: [WatchCompletedExercise] = []) {
        let id = UUID().uuidString
        let item = PendingWorkoutToSend(
            id: id,
            activityType: activityType,
            completedAtTimestamp: completedAt.timeIntervalSince1970,
            durationSeconds: durationSeconds,
            exercises: exercises
        )
        var pending = PendingWorkoutsStore.load()
        pending.append(item)
        PendingWorkoutsStore.save(pending)
        pendingWorkoutCount = pending.count
        sendPayload(for: item)
    }

    /// Resend all pending workouts to the phone (e.g. after transfer failed or user taps retry).
    func retrySyncing() {
        resendPendingWorkouts()
    }

    private func sendPayload(for item: PendingWorkoutToSend) {
        guard WCSession.default.activationState == .activated else { return }
        var payload: [String: Any] = [
            WatchWorkoutPayload.id: item.id,
            WatchWorkoutPayload.activityType: item.activityType,
            WatchWorkoutPayload.completedAtTimestamp: item.completedAtTimestamp,
            WatchWorkoutPayload.durationSeconds: item.durationSeconds
        ]
        let exerciseDicts = item.exercises.map { ["title": $0.title, "durationSeconds": $0.durationSeconds] as [String: Any] }
        payload[WatchWorkoutPayload.exercises] = exerciseDicts
        WCSession.default.transferUserInfo([WatchWorkoutPayload.key: payload])
    }

    private func resendPendingWorkouts() {
        let pending = PendingWorkoutsStore.load()
        for item in pending {
            sendPayload(for: item)
        }
    }

    private func removePending(ackId: String) {
        var pending = PendingWorkoutsStore.load()
        pending.removeAll { $0.id == ackId }
        PendingWorkoutsStore.save(pending)
        pendingWorkoutCount = pending.count
    }
}

extension WatchWorkoutSender: WCSessionDelegate {
    nonisolated(unsafe) func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor [weak self] in
            self?.resendPendingWorkouts()
        }
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let ackId = userInfo[WatchWorkoutAck.key] as? String else { return }
        Task { @MainActor [weak self] in
            self?.removePending(ackId: ackId)
        }
    }
}
